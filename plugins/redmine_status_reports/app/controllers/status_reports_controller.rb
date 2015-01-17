# encoding: utf-8 
class StatusReportsController < ApplicationController
 
  unloadable

  helper :queries
  include QueriesHelper
  helper :sort
  include SortHelper

  def index
    @id=params[:id]
    @status_by_id = by_id(@id)
  end

  def show
  end
  
  def otro(id)
    ActiveRecord::Base.connection.select_all("(select u.firstname || ' ' || u.lastname as \"new_state\"
     from journal_details jd,
     users u,
     users ue,
     journals j
where jd.prop_key='assigned_to_id' and
jd.old_value = CAST(u.id AS CHAR(4)) and
      jd.value = CAST(ue.id AS CHAR(4)) and
      jd.journal_id=j.id and
      jd.journal_id=(select min(journal_id) from journal_details where prop_key='assigned_to_id' and journal_id in (select id from journals where journalized_id=#{id}))
order by 1)")
  end
  
  def by_id(id)
    ActiveRecord::Base.connection.select_all("(select jd.id,
       ie.name as \"old_state\",
       iee.name as \"new_state\",
       j.created_on as \"state_date_changed\",
       j.journalized_id as \"issue_id\",
       jd.journal_id as \"jdID\",
       jd.prop_key as \"prop_key\",
       (select name from projects where id=(select project_id from issues where id=#{id})) as \"nombre_proyecto\"
from journal_details jd,
     issue_statuses ie,
     issue_statuses iee,
     journals j
where jd.prop_key='status_id' and
      jd.old_value = CAST(ie.id AS CHAR(4)) and
      jd.value = CAST(iee.id AS CHAR(4)) and
      jd.journal_id=j.id and
      jd.journal_id in (select journal_id from journal_details where prop_key='status_id' and journal_id in (select id from journals where journalized_id=#{id}))
order by jd.id)")
  end
  
  def by_mas(id,ids)
    ActiveRecord::Base.connection.select_all("(select distinct jd.id as \"id\",
u.firstname || ' ' || u.lastname as \"new_state\",
       (select iee.name as \"new_state\"
from journal_details jd,
     issue_statuses ie,
     issue_statuses iee,
     journals j
where jd.prop_key='status_id' and
      jd.old_value = CAST(ie.id AS CHAR(4)) and
      jd.value = CAST(iee.id AS CHAR(4)) and
      jd.journal_id=j.id and
      jd.journal_id = (select max(journal_id) from journal_details where prop_key='status_id' and journal_id in (select id from journals where journalized_id=#{id}) and journal_id <#{ids})
order by 1)
 as \"new_state_estado\",
       j.created_on as \"state_date_changed\",
       j.journalized_id as \"issue_id\",
       jd.journal_id as \"jdID\",
       jd.prop_key as \"prop_key\",
       (select name from projects where id=(select project_id from issues where id=#{id})) as \"nombre_proyecto\"
from journal_details jd,
     users u,
     users ue,
     journals j
where jd.prop_key='assigned_to_id' and
jd.old_value = CAST(u.id AS CHAR(4)) and
      jd.value = CAST(ue.id AS CHAR(4)) and
      jd.journal_id=j.id and
      jd.journal_id=#{ids}
order by 1)")
  end
  
  def by_mas_mas(id)
    ActiveRecord::Base.connection.select_values("(select journal_id from journal_details where prop_key='assigned_to_id' and journal_id not in (select journal_id from journal_details where prop_key='status_id' and journal_id in (select id from journals where journalized_id=#{id}) order by journal_id)
 and journal_id in (select id from journals where journalized_id=#{id}) order by journal_id)")
  end
  
  def nombre_proyecto_issues(id)
    ActiveRecord::Base.connection.select_value("select name from projects where id=(select project_id from issues where id=#{id})")
  end
  
  def fecha_anterior(id, ids)
    ActiveRecord::Base.connection.select_value("select created_on from journals where id=(select max(journal_id) from journal_details where id<#{ids} and id in(select id from journal_details where journal_id in (select id from journals where journalized_id=#{id}) order by 1))")
  end
  
  def numero_usuario(ids)
    ActiveRecord::Base.connection.select_value("select user_id from journals where id=#{ids}")
  end
  
  def otro_numero_usuario(ids)
    ActiveRecord::Base.connection.select_value("select old_value from journal_details where journal_id=#{ids} and prop_key='assigned_to_id'")
  end
 
  def otros_numero_usuario(ids)
    ActiveRecord::Base.connection.select_value("select value from journal_details where journal_id=#{ids} and prop_key='assigned_to_id'")
  end
  
  def report
    @project = Project.find params[:project_id]
   
    ###
    retrieve_query
    #    sort_init(@query.sort_criteria.empty? ? [['id', 'desc']] : @query.sort_criteria)
    #    sort_update(@query.sortable_columns)
    
    if @query.valid?
      @limit = Setting.issues_export_limit.to_i

      @issue_count = @query.issue_count
      @issue_pages = Paginator.new self, @issue_count, @limit, params['page']
      @offset ||= @issue_pages.current.offset
      @issues = @query.issues(:include => [:assigned_to, :tracker, :priority, :category, :fixed_version],
        #        :order => sort_clause,
        :offset => @offset,
        :limit => @limit)

      @iss = []
      @issues.each{|i|
        issue = Issue.find i.id
        @iss << issue
      }
      respond_to do |format|
        format.html { send_data(statuses_to_csv(@iss, @project), :type => 'text/csv; header=present', :filename => 'export.csv')  }
      end      
    end
    ###
  end

  def entries_without_answer_report
    project = params[:project_id]
    require "rbconfig"
    config   = Rails.configuration.database_configuration
    adapter = config[Rails.env]["adapter"]
    jndi = config[Rails.env]["jndi"]
     
    #    require 'java'
    require Rails.root.join("dist/consulta.jar")
     
    java_import Java::consulta.ReporteEntradasSinRespuesta
    
    reporte = ReporteEntradasSinRespuesta.new()
    arr = []
    arr[0]= project
    arr[1]= ''     
    arr[2]= adapter
    arr[3]= jndi
    @content = reporte.ejecutarReporte(arr)
  end
  
  def report_close_policity
    @content1 = "<html><table border='1'> <tr><td><h4>Proyecto</h4></td><td><h4>Número de caso</h4></td><td><h4>Estado</h4></td><td><h4>Días</h4></td></tr>\n";
      
    @project = Project.find params[:project_id]
    projects = Project.find(:all, :conditions => ["parent_id=?", @project.id])
    
    if @project.id == 10
      issues = Issue.find(:all, :conditions => ["project_id IN (?) and status_id IN ('24', '27', '12', '5', '46')", projects ])
      final_journals_details = []
      
      issues.each { |caso|  
        journals = Journal.find(:all, :conditions => ["journalized_id=?", caso.id ])
        journals_details_state = JournalDetail.find(:all, :conditions=> ["prop_key='status_id' and value IN ('24', '27', '12', '5', '46') and journal_id in (?)", journals])
        journals_details_state_tmp = []
        journals_details_state.each { |jd|
          journals_details_state_tmp << jd.journal_id
        }
        final_journals_details  << journals_details_state_tmp.last }
      
      final_journals = Journal.find(:all, :conditions=> ["id in (?)", final_journals_details])

      final_journals.each { |item|  
        @date_update = item.created_on
        @days = Time.now - @date_update
        @total_days = ((@days.to_f * 1000.0).to_i)/ 86400000
        if @total_days > 15
          @issue = Issue.find(item.journalized_id)
          @content1 = @content1 + "<tr><td> #{@issue.project}</td> <td>#{item.journalized_id}</td> <td>#{@issue.status}</td> <td>#{@total_days}</td></tr> "
        end
      }
      @content = @content1  + "</table></html>"
     
    elsif @project.id == 103
      issues_capital_mb = Issue.find(:all, :conditions => ["project_id IN ('79', '117') and tracker_id = ('6') and status_id IN ('24', '12')"])
      issues_mavesa = Issue.find(:all, :conditions => ["project_id =159  and status_id IN ('24', '27','46')"])
        
      journals_details_mb = []
      journals_details_mv = []
      
      issues_capital_mb.each { |caso_cm|  
        journals = Journal.find(:all, :conditions => ["journalized_id=?", caso_cm.id ])
        journals_details_state = JournalDetail.find(:all, :conditions=> ["prop_key='status_id' and value IN ('24', '12') and journal_id in (?)", journals])
        journals_details_state_tmp = []
        journals_details_state.each { |jd|
          journals_details_state_tmp << jd.journal_id
        }
        journals_details_mb  << journals_details_state_tmp.last
      }
   
      issues_mavesa.each { |caso_mv|  
        journals = Journal.find(:all, :conditions => ["journalized_id=?", caso_mv.id ])
        journals_details_state = JournalDetail.find(:all, :conditions=> ["prop_key='status_id' and value IN ('24', '27', '46') and journal_id in (?)", journals])
        journals_details_state_tmp = []
        journals_details_state.each { |jd|
          journals_details_state_tmp << jd.journal_id
        }
        journals_details_mv  << journals_details_state_tmp.last
      }
        
      journals_cap_mb = Journal.find(:all, :conditions=> ["id in (?)", journals_details_mb])
      journals_mavesa = Journal.find(:all, :conditions=> ["id in (?)", journals_details_mv])
 
      journals_cap_mb.each { |item|  
        @date_update = item.created_on
        @days = Time.now - @date_update
        @total_days = ((@days.to_f * 1000.0).to_i)/ 86400000
        if @total_days > 30
          @issue = Issue.find(item.journalized_id)
          @content1 = @content1 + "<tr><td> #{@issue.project}</td> <td>#{item.journalized_id}</td> <td>#{@issue.status}</td> <td>#{@total_days}</td></tr> "
        end
      }
      journals_mavesa.each { |item|  
        @date_update = item.created_on
        @days = Time.now - @date_update
        @total_days = ((@days.to_f * 1000.0).to_i)/ 86400000
        if @total_days > 60
          @issue = Issue.find(item.journalized_id)
          @content1 = @content1 + "<tr><td> #{@issue.project}</td> <td>#{item.journalized_id}</td> <td>#{@issue.status}</td> <td>#{@total_days}</td></tr> "
        end
      }
      @content = @content1  + "</table></html>"
    end
  end
  
  #Funciones reporte estados
  def max_journal_assigned_user(jdID,id)
    ActiveRecord::Base.connection.select_value("select value from journal_details where journal_id=(select max(journal_id) from journal_details where journal_id<#{jdID} and prop_key='assigned_to_id' and journal_id in (select id from journals where journalized_id=#{id})) and prop_key='assigned_to_id'")
  end
  
  def by_custom_devoluciones(id)
    ActiveRecord::Base.connection.select_all("select journal_id as \"jdID\", prop_key as \"custom_field_id\",value as \"valor\" from journal_details where journal_id in(select id from journals where journalized_id=#{id}) and property='cf' and prop_key in ('23','36','82','112')")
  end
  
  def by_custom_devoluciones_validacion(id)
    ActiveRecord::Base.connection.select_all("select journal_id as \"jdID\", prop_key as \"custom_field_id\",value as \"valor\" from journal_details where journal_id in(select id from journals where journalized_id=#{id}) and property='cf' and prop_key in ('23','36','82','112')
union
(select journal_id as \"jdID\",CAST(36 AS CHAR(4)),CAST(1 AS CHAR(4)) from journal_details where journal_id in(select id from journals where journalized_id=#{id}) and prop_key='status_id' and value='17' order by 1  limit 1)")
  end
  
  def ultimo_cambio_motivo_devolucion_cliente(jdID,custom_field,id,custom_field_2)
    ActiveRecord::Base.connection.select_value("(select max(journal_id) from journal_details where journal_id in(
select journal_id from journal_details where journal_id in(select id from journals where journalized_id=#{id}) and property='cf' and prop_key in ('#{custom_field}') and journal_id>#{jdID} and 
journal_id<(select min(journal_id) from journal_details where journal_id in(select id from journals where journalized_id=#{id}) and prop_key=('#{custom_field_2}') and journal_id>#{jdID})
))")
  end
  
  def ultimo_cambio_motivo_devolucion_ultimo_registro(jdID,custom_field,id)
    ActiveRecord::Base.connection.select_value("(select max(journal_id) from journal_details where journal_id in(
select journal_id from journal_details where journal_id in(select id from journals where journalized_id=#{id}) and property='cf' and prop_key in ('#{custom_field}') and journal_id>#{jdID}
)) ")
  end
  
  def valor_maximmo_motivos_devolucion(id,custom_field)
    ActiveRecord::Base.connection.select_value("select max(journal_id) from journal_details where journal_id in(select id from journals where journalized_id=#{id}) and prop_key='#{custom_field}'")
  end
  
  def valor_siguiente_devoluciones(id,custom_field,jdID)
    ActiveRecord::Base.connection.select_value("select min(journal_id) from journal_details where journal_id in(select id from journals where journalized_id=#{id}) and journal_id>#{jdID} and prop_key='#{custom_field}' ")
  end
  
  def valor_inicial_devoluciones(id,custom_field)
    ActiveRecord::Base.connection.select_value("select journal_id from journal_details where journal_id in (select id from journals where journalized_id=#{id}) and prop_key='#{custom_field}' and value='1'")
  end
  
  def valor_motivos_entre_estados(jdID,custom_field,id)
    ActiveRecord::Base.connection.select_value("select value from journal_details where journal_id=
(select max(journal_id) from journal_details where journal_id>#{jdID} and journal_id<
(select min(journal_id) from journal_details where journal_id in(select id from journals where journalized_id=#{id}) and prop_key='status_id' and journal_id>#{jdID}) 
and prop_key='#{custom_field}') 
and prop_key='#{custom_field}'")
  end
  #Fin funciones
  def statuses_to_csv(issues, project = nil)
    #    ic = Iconv.new(l(:general_csv_encoding), 'UTF-8')
    encoding = l(:general_csv_encoding)
    export = FCSV.generate(:col_sep => l(:general_csv_separator)) do |csv|
      # csv header fields
      headers = [ "#",
        l(:field_status),
        l(:field_project),
        "Asunto",
        "Asignado A",
        "Rol",
        "Version Prevista",
        "Creado",
        "Módulo",
        "Módulo Aplicación",
        "Fecha Inicio",
        "No. Devoluciones Interno",
        "Motivo Devolucion", 
        "No. Devoluciones Cliente",
        "Motivo Devolucion Cliente"
      ]
      #      csv << headers.collect {|c| begin; ic.iconv(c.to_s); rescue; c.to_s; end }
      csv << headers.collect {|c| Redmine::CodesetUtil.from_utf8(c.to_s, encoding) }
      
      @cf=CustomField.find_by_id(36)
      if @project.all_issue_custom_fields.include? (@cf)
        @valor_proyecto_custom_devoluciones=1
      end
      
      issues.each{|issue|
        # csv lines
        #variables para devoluciones
        @custom_devuelto_by_id=by_custom_devoluciones(issue.id)
        #Fin
        
        #Validacion en primer cambio de estado a Devuelta
        if !@valor_proyecto_custom_devoluciones.blank?
          @custom_devuelto_by_id=by_custom_devoluciones_validacion(issue.id)
        else
          @custom_devuelto_by_id=by_custom_devoluciones(issue.id)
        end
        #Fin
        
        @status_by_id = by_id(issue.id)
        #Valor de modulo y modulo aplicacion cuando no se modifican los valores en los journals
        @valor_modulo=CustomValue.find_by_customized_id_and_custom_field_id(issue.id,5)
        @valor_modulo_aplicacion=CustomValue.find_by_customized_id_and_custom_field_id(issue.id,17)
        #Fin valor de modulo

        if @status_by_id.count>0
          @first=@status_by_id.first
          @status_by_id.each do |state|
            @valor_devoluciones_internas=''
            @valor_devoluciones_cliente=''
            @motivo_devoluciones=''
            @motivo_devoluciones_cliente=''
            @version=''
            @rol_name=''
            @issue = Issue.find state["issue_id"]
            
            #Version prevista
            if !@issue.fixed_version_id.blank?
              @version=Version.find(@issue.fixed_version_id).name
            end
            #Fin Version
            ##Asunto
            @asunto=@issue.subject
            #Fin Asunto
            #Creado
            @creado=@issue.created_on
            #Fin Creado
            #
            #Validacion primera devolucion
            @journal_inicial_interno=valor_inicial_devoluciones(@issue.id,'23')
            @journal_inicial_cliente=valor_inicial_devoluciones(@issue.id,'36')
            #Fin
            
            s=@status_by_id.index(state)-1
            @jd=JournalDetail.find_by_journal_id_and_prop_key(state["jdID"],"assigned_to_id")
            #Cuando solo hay cambio de estado sin cambio de asignado el jd es vacio
            if @jd.nil?
              @jd_extra=nil
            else
              @jd_extra=JournalDetail.find(@jd.id)
            end
              
            if state==@first
              @last = nil
              if @jd_extra.nil?
                @user=User.find(numero_usuario(state["jdID"]))
              else
                if @jd_extra.old_value.blank?
                  @user = User.new
                  @user.firstname=""
                  @user.lastname=""
                else
                  @user=User.find(@jd_extra.old_value)
                end
              end
              #Asignacion de rol
              member = Member.find_by_user_id_and_project_id(@user.id, @issue.project_id)
              member_roles = MemberRole.find_all_by_member_id(member)
              member_roles.each do |memberRole|
                if memberRole.role_id.to_i==101 or memberRole.role_id.to_i==55 or memberRole.role_id.to_i==12 or memberRole.role_id.to_i==44 or memberRole.role_id.to_i==43 or memberRole.role_id.to_i==45 or memberRole.role_id.to_i==4 or memberRole.role_id.to_i==46 or memberRole.role_id.to_i==36 or memberRole.role_id.to_i==54 or memberRole.role_id.to_i==10 or memberRole.role_id.to_i==11
                  rol = Role.find_by_id(memberRole.role_id)
                  @rol_name=rol.name
                end
              end
              #Fin asignacion
              #V-Devoluciones
              if @custom_devuelto_by_id.count>0
                @custom_devuelto_by_id.each do |state_devoluciones|
                  if state_devoluciones["jdID"].to_s==state["jdID"].to_s
                    case state_devoluciones["custom_field_id"].to_s
                    when '23'
                      if state_devoluciones["valor"].to_s!='0'
                        @valor_devoluciones_internas=state_devoluciones["valor"]
                      end
                    when '36'
                      if state_devoluciones["valor"].to_s!='0'
                        @valor_devoluciones_cliente=state_devoluciones["valor"]
                      end
                    when '82'
                      if state_devoluciones["jdID"].to_i>=@journal_inicial_interno.to_i
                        @motivo_devoluciones=state_devoluciones["valor"]
                      end
                    when '112'
                      if state_devoluciones["jdID"].to_i>=@journal_inicial_cliente.to_i
                        @motivo_devoluciones_cliente=state_devoluciones["valor"]
                      end
                    end
                  end
                end
              end
              #Fin V-Devoluciones
              if @valor_devoluciones_internas.blank?
                @motivo_devoluciones=''
              end
              if @valor_devoluciones_cliente.blank?
                @motivo_devoluciones_cliente=''
              end
              fields = [state["issue_id"],
                state["old_state"],
                state["nombre_proyecto"],
                @asunto,
                "#{@user.firstname} #{@user.lastname}",
                @rol_name,
                @version,
                @creado,
                @valor_modulo,
                @valor_modulo_aplicacion,
                @creado,
                @valor_devoluciones_internas,
                @motivo_devoluciones, 
                @valor_devoluciones_cliente,
                @motivo_devoluciones_cliente
              ]
            else
              @valor_devoluciones_internas=''
              @valor_devoluciones_cliente=''
              @motivo_devoluciones=''
              @motivo_devoluciones_cliente=''
              @ultimo_journal_detail_interno=''
              @ultimo_journal_detail_cliente=''
              @rol_name=''
              if @jd_extra.nil?
                @usuario_anterior_cambio_asignado=max_journal_assigned_user(state["jdID"],state["issue_id"])
                if !@usuario_anterior_cambio_asignado.blank?
                  @user=User.find(@usuario_anterior_cambio_asignado)
                else
                  @user=User.find(numero_usuario(state["jdID"]))
                end
              else
                id_old=@jd_extra.old_value
                id_new=@jd_extra.value
                if id_old==@last_id
                  if @last_id.blank?
                    @user = User.new
                    @user.firstname=""
                    @user.lastname=""
                  else
                    @user=User.find(@last_id)
                  end
                else
                  if id_old.blank?
                    @user = User.new
                    @user.firstname=""
                    @user.lastname=""
                  else
                    @user=User.find(id_old)
                  end
                end
                @last_id = id_new
                if @last_id.blank?
                  @user=User.find(otro_numero_usuario(state["jdID"]))
                else
                  @last = User.find(@last_id)
                end
              end
              #Asignacion de rol
              member = Member.find_by_user_id_and_project_id(@user.id, @issue.project_id)
              member_roles = MemberRole.find_all_by_member_id(member)
              member_roles.each do |memberRole|
                if memberRole.role_id.to_i==101 or memberRole.role_id.to_i==55 or memberRole.role_id.to_i==12 or memberRole.role_id.to_i==44 or memberRole.role_id.to_i==43 or memberRole.role_id.to_i==45 or memberRole.role_id.to_i==4 or memberRole.role_id.to_i==46 or memberRole.role_id.to_i==36 or memberRole.role_id.to_i==54 or memberRole.role_id.to_i==10 or memberRole.role_id.to_i==11
                  rol = Role.find_by_id(memberRole.role_id)
                  @rol_name=rol.name
                end
              end
              #Fin asignacion
              #V-Devoluciones
              if @custom_devuelto_by_id.count>0
                @custom_devuelto_by_id.each do |state_devoluciones|
                  if state_devoluciones["jdID"].to_s==@status_by_id.at(s)["jdID"].to_s
                    case state_devoluciones["custom_field_id"].to_s
                    when '23'
                      if state_devoluciones["valor"].to_s!='0'
                        @valor_devoluciones_internas=state_devoluciones["valor"]
                      end
                    when '36'
                      if state_devoluciones["valor"].to_s!='0'
                        @valor_devoluciones_cliente=state_devoluciones["valor"]
                      end
                    when '82'
                      if state_devoluciones["jdID"].to_i>=@journal_inicial_interno.to_i
                        @valor_de_siguiente_devolucion=valor_siguiente_devoluciones(state["issue_id"],'23',state_devoluciones["jdID"])
                        @valor_ultimo_motivo=valor_maximmo_motivos_devolucion(state["issue_id"],'82')
                        if @valor_de_siguiente_devolucion.blank?
                          @valor_motivo=JournalDetail.find_by_journal_id_and_prop_key(@valor_ultimo_motivo,'82').value
                          @motivo_devoluciones=@valor_motivo
                        else
                          @ultimo_journal_detail_interno=ultimo_cambio_motivo_devolucion_cliente(state_devoluciones["jdID"],'82',state["issue_id"],'23')
                          if !@ultimo_journal_detail_interno.blank?
                            @valor_interno=JournalDetail.find_by_journal_id_and_prop_key(@ultimo_journal_detail_interno,'82').value
                            @motivo_devoluciones=@valor_interno
                          else
                            @motivo_devoluciones=state_devoluciones["valor"]
                          end
                        end
                      end
                    when '112'
                      if state_devoluciones["jdID"].to_i>=@journal_inicial_cliente.to_i
                        @valor_de_siguiente_devolucion_cliente=valor_siguiente_devoluciones(state["issue_id"],'36',state_devoluciones["jdID"])
                        @valor_ultimo_motivo_cliente=valor_maximmo_motivos_devolucion(state["issue_id"],'112')
                        if @valor_de_siguiente_devolucion_cliente.blank?
                          @valor_motivo_cliente=JournalDetail.find_by_journal_id_and_prop_key(@valor_ultimo_motivo_cliente,'112').value
                          @motivo_devoluciones_cliente=@valor_motivo_cliente
                        else
                          @ultimo_journal_detail_cliente=ultimo_cambio_motivo_devolucion_cliente(state_devoluciones["jdID"],'112',state["issue_id"],'36')
                          if !@ultimo_journal_detail_cliente.blank?
                            @valor=JournalDetail.find_by_journal_id_and_prop_key(@ultimo_journal_detail_cliente,'112').value
                            @motivo_devoluciones_cliente=@valor
                          else
                            @motivo_devoluciones_cliente=state_devoluciones["valor"]
                          end
                        end
                      end
                    end
                  end
                end
              end
              #Fin V-Devoluciones
              if @valor_devoluciones_internas.blank?
                @motivo_devoluciones=''
              end
              if @valor_devoluciones_cliente.blank?
                @motivo_devoluciones_cliente=''
              end
              fields = [state["issue_id"],
                state["old_state"],
                state["nombre_proyecto"],
                @asunto,
                "#{@user.firstname} #{@user.lastname}",
                @rol_name,
                @version,
                @creado,
                @valor_modulo,
                @valor_modulo_aplicacion,
                ((@status_by_id.at(s))["state_date_changed"]).to_datetime.strftime("%m/%d/%Y %H:%M"),
                @valor_devoluciones_internas,
                @motivo_devoluciones,
                @valor_devoluciones_cliente,
                @motivo_devoluciones_cliente
              ]
            end
            #            csv << fields.collect {|c| begin; ic.iconv(c.to_s); rescue; c.to_s; end }
            csv << fields.collect {|c| Redmine::CodesetUtil.from_utf8(c.to_s, encoding) }
          end
            
          @jd=JournalDetail.find_by_journal_id_and_prop_key((@status_by_id.last)["jdID"],"assigned_to_id")
          if @jd.nil?
            @jd_extra = nil
          else
            @jd_extra = JournalDetail.find(@jd.id)
          end
            
          if @jd_extra.nil?
            @user = @last
            if @user.nil?
              @user = User.new
              @user.firstname=""
              @user.lastname=""
            end
          else
            id_new=@jd_extra.value
            if id_new==@last
              if @last.blank?
                @user = User.new
                @user.firstname=""
                @user.lastname=""
              else
                @user=User.find(@last)
              end
            else
              if id_new.blank?
                @user = User.new
                @user.firstname=""
                @user.lastname=""
              else
                @user=User.find(id_new)
              end
            end
          end
          #Asignacion de rol
          @rol_name=''
          member = Member.find_by_user_id_and_project_id(@user.id, @issue.project_id)
          member_roles = MemberRole.find_all_by_member_id(member)
          member_roles.each do |memberRole|
            if memberRole.role_id.to_i==101 or memberRole.role_id.to_i==55 or memberRole.role_id.to_i==12 or memberRole.role_id.to_i==44 or memberRole.role_id.to_i==43 or memberRole.role_id.to_i==45 or memberRole.role_id.to_i==4 or memberRole.role_id.to_i==46 or memberRole.role_id.to_i==36 or memberRole.role_id.to_i==54 or memberRole.role_id.to_i==10 or memberRole.role_id.to_i==11
              rol = Role.find_by_id(memberRole.role_id)
              @rol_name=rol.name
            end
          end
          #Fin asignacion
          #V-Devoluciones
          @valor_devoluciones_internas=''
          @valor_devoluciones_cliente=''
          @motivo_devoluciones=''
          @motivo_devoluciones_cliente=''
          @ultimo_journal_detail_interno=''
          @ultimo_journal_detail=''

          if @custom_devuelto_by_id.count>0
            @custom_devuelto_by_id.each do |state_devoluciones|
              if state_devoluciones["jdID"].to_s==@status_by_id.last["jdID"].to_s
                case state_devoluciones["custom_field_id"].to_s
                when '23'
                  @valor_devoluciones_internas=state_devoluciones["valor"]
                when '36'
                  @valor_devoluciones_cliente=state_devoluciones["valor"]
                when '82'
                  @ultimo_journal_detail_interno=ultimo_cambio_motivo_devolucion_ultimo_registro(state_devoluciones["jdID"],'82',@status_by_id.last["issue_id"])
                  if !@ultimo_journal_detail_interno.blank?
                    @valor_interno=JournalDetail.find_by_journal_id_and_prop_key(@ultimo_journal_detail_interno,'82').value
                    @motivo_devoluciones=@valor_interno
                  else
                    @motivo_devoluciones=state_devoluciones["valor"]
                  end
                when '112'
                  @ultimo_journal_detail=ultimo_cambio_motivo_devolucion_ultimo_registro(state_devoluciones["jdID"],'112',@status_by_id.last["issue_id"])
                  if !@ultimo_journal_detail.blank?
                    @valor=JournalDetail.find_by_journal_id_and_prop_key(@ultimo_journal_detail,'112').value
                    @motivo_devoluciones_cliente=@valor
                  else
                    @motivo_devoluciones_cliente=state_devoluciones["valor"]
                  end
                end   
              end
            end
          end
          #Fin V-Devoluciones
          if @valor_devoluciones_internas.blank?
            @motivo_devoluciones=''
          end
          if @valor_devoluciones_cliente.blank?
            @motivo_devoluciones_cliente=''
          end
          fields = [(@status_by_id.last)["issue_id"],
            (@status_by_id.last)["new_state"],
            (@status_by_id.last)["nombre_proyecto"],
            @asunto,
            "#{@user.firstname} #{@user.lastname}",
            @rol_name,
            @version,
            @creado,
            @valor_modulo,
            @valor_modulo_aplicacion,
            (@status_by_id.last)["state_date_changed"].to_datetime.strftime("%m/%d/%Y %H:%M"),
            @valor_devoluciones_internas,
            @motivo_devoluciones,
            @valor_devoluciones_cliente,
            @motivo_devoluciones_cliente
          ]
          #          csv << fields.collect {|c| begin; ic.iconv(c.to_s); rescue; c.to_s; end }
          csv << fields.collect {|c| Redmine::CodesetUtil.from_utf8(c.to_s, encoding) }
        else
          i=Issue.find issue.id
          #Version prevista
          if !i.fixed_version_id.blank?
            @version=Version.find(i.fixed_version_id).name
          end
          #Fin Version
          ##Asunto
          @asunto=i.subject
          #Fin Asunto
          #Creado
          @creado=i.created_on
          #Fin Creado
          if (i.assigned_to_id).blank?
            @user_name = ""
          else
            @user_name = (User.find i.assigned_to_id).name
          end
          @pro_i=nombre_proyecto_issues(i.id)
          #Asignacion de rol
          @rol_name=''
          member = Member.find_by_user_id_and_project_id(@user.id, i.project_id)
          member_roles = MemberRole.find_all_by_member_id(member)
          member_roles.each do |memberRole|
            if memberRole.role_id.to_i==55 or memberRole.role_id.to_i==12 or memberRole.role_id.to_i==44 or memberRole.role_id.to_i==43 or memberRole.role_id.to_i==45 or memberRole.role_id.to_i==4 or memberRole.role_id.to_i==46 or memberRole.role_id.to_i==36 or memberRole.role_id.to_i==54 or memberRole.role_id.to_i==10 or memberRole.role_id.to_i==11
              rol = Role.find_by_id(memberRole.role_id)
              @rol_name=rol.name
            end
          end
          #Fin asignacion
          #Devoluciones
          @valor_devoluciones_internas=''
          @valor_devoluciones_cliente=''
          @motivo_devoluciones=''
          @motivo_devoluciones_cliente=''
          #Fin Dvoluciones
          fields = [i.id,
            (IssueStatus.find i.status_id).name,
            @pro_i,
            @asunto,
            @user_name,
            @rol_name,
            @version,
            @creado,
            @valor_modulo,
            @valor_modulo_aplicacion,
            (i.created_on).strftime("%m/%d/%Y %H:%M"),
            @valor_devoluciones_internas,
            @motivo_devoluciones,
            @valor_devoluciones_cliente,
            @motivo_devoluciones_cliente
          ]
          #          csv << fields.collect {|c| begin; ic.iconv(c.to_s); rescue; c.to_s; end }
          csv << fields.collect {|c| Redmine::CodesetUtil.from_utf8(c.to_s, encoding) }
        end
      }
    end
    export
  end 

  def distance_of_time_in_words(from_time, to_time = 0, include_seconds = false, options = {})
    from_time = from_time.to_time if from_time.respond_to?(:to_time)
    to_time = to_time.to_time if to_time.respond_to?(:to_time)
    distance_in_minutes = (((to_time - from_time).abs)/60).round
    distance_in_seconds = ((to_time - from_time).abs).round

    I18n.with_options :locale => options[:locale], :scope => :'datetime.distance_in_words' do |locale|
      case distance_in_minutes
      when 0..1
        return distance_in_minutes == 0 ?
          locale.t(:less_than_x_minutes, :count => 1) :
          locale.t(:x_minutes, :count => distance_in_minutes) unless include_seconds

        case distance_in_seconds
        when 0..4   then locale.t :less_than_x_seconds, :count => 5
        when 5..9   then locale.t :less_than_x_seconds, :count => 10
        when 10..19 then locale.t :less_than_x_seconds, :count => 20
        when 20..39 then locale.t :half_a_minute
        when 40..59 then locale.t :less_than_x_minutes, :count => 1
        else             locale.t :x_minutes,           :count => 1
        end

      when 2..44           then locale.t :x_minutes,      :count => distance_in_minutes
      when 45..89          then locale.t :about_x_hours,  :count => 1
      when 90..1439        then locale.t :about_x_hours,  :count => (distance_in_minutes.to_f / 60.0).round
      when 1440..2529      then locale.t :x_days,         :count => 1
      when 2530..43199     then locale.t :x_days,         :count => (distance_in_minutes.to_f / 1440.0).round
      when 43200..86399    then locale.t :about_x_months, :count => 1
      when 86400..525599   then locale.t :x_months,       :count => (distance_in_minutes.to_f / 43200.0).round
      else
        distance_in_years           = distance_in_minutes / 525600
        minute_offset_for_leap_year = (distance_in_years / 4) * 1440
        remainder                   = ((distance_in_minutes - minute_offset_for_leap_year) % 525600)
        if remainder < 131400
          locale.t(:about_x_years,  :count => distance_in_years)
        elsif remainder < 394200
          locale.t(:over_x_years,   :count => distance_in_years)
        else
          locale.t(:almost_x_years, :count => distance_in_years + 1)
        end
      end
    end
  end
  
  # Initializes the default sort.
  # Examples:
  #   
  #   sort_init 'name'
  #   sort_init 'id', 'desc'
  #   sort_init ['name', ['id', 'desc']]
  #   sort_init [['name', 'desc'], ['id', 'desc']]
  #
  def sort_init(*args)
    case args.size
    when 1
      @sort_default = args.first.is_a?(Array) ? args.first : [[args.first]]
    when 2
      @sort_default = [[args.first, args.last]]
    else
      raise ArgumentError
    end
  end
  
  
  #Requerimiento 35603

  #Funciones reporte de actividades
  def estado_mas(id)
    ActiveRecord::Base.connection.select_all("(select jd.id,
 ie.name as \"old_state\",
 iee.name as \"new_state\",
 j.created_on as \"state_date_changed\",
 j.journalized_id as \"issue_id\",
 jd.journal_id as \"jdID\",
 jd.prop_key as \"prop_key\",
 (select name from projects where id=(select project_id from issues where id=#{id})) as \"nombre_proyecto\",
(select u.firstname || ' ' || u.lastname from users u where cast(id as char(4))=(select value from journal_details where journal_id=(select max(journal_id) from journal_details where journal_id<jd.journal_id and prop_key='assigned_to_id' and journal_id in(select id from journals where journalized_id=#{id}) order by 1) and prop_key='assigned_to_id')) as \"asignado\",
 (select created_on from journals where id=(select max(journal_id) from journal_details where journal_id in(select id from journals where journalized_id=#{id}) and (prop_key='status_id' or prop_key='assigned_to_id') and journal_id<jd.journal_id)) as \"fecha_inicio\"
from journal_details jd,
 issue_statuses ie,
 issue_statuses iee,
 journals j
where jd.prop_key='status_id' and
 jd.old_value = CAST(ie.id AS CHAR(4)) and
 jd.value = CAST(iee.id AS CHAR(4)) and
 jd.journal_id=j.id and
 jd.journal_id in (select journal_id from journal_details where journal_id in (select id from journals where journalized_id=#{id}) and prop_key='status_id' and journal_id not in (select journal_id from journal_details where journal_id in (select id from journals where journalized_id=#{id}) and prop_key='assigned_to_id' ))
order by 1)")
  end
  
  def asignado_mas(id)
    ActiveRecord::Base.connection.select_all("(select jd.id,
 u.firstname || ' ' || u.lastname as \"old_state\",
 ue.firstname || ' ' || ue.lastname as \"new_state\",
 j.created_on as \"state_date_changed\",
 j.journalized_id as \"issue_id\",
 jd.journal_id as \"jdID\",
 jd.prop_key as \"prop_key\",
 (select name from projects where id=(select project_id from issues where id=#{id})) as \"nombre_proyecto\",
 (select name from issue_statuses where cast(id as char(4))=(select value from journal_details where journal_id=(select max(journal_id) from journal_details where prop_key='status_id' and journal_id in (select id from journals where journalized_id=#{id}) and journal_id <jd.journal_id) and prop_key='status_id')) as \"estado\",
 (select created_on from journals where id=(select max(journal_id) from journal_details where journal_id in(select id from journals where journalized_id=#{id}) and (prop_key='status_id' or prop_key='assigned_to_id') and journal_id<jd.journal_id)) as \"fecha_inicio\"
from journal_details jd,
 users u,
 users ue,
 journals j
where jd.prop_key='assigned_to_id' and
 jd.old_value = CAST(u.id AS CHAR(4)) and
 jd.value = CAST(ue.id AS CHAR(4)) and
 jd.journal_id=j.id and
 jd.journal_id in (select journal_id from journal_details where journal_id in (select id from journals where journalized_id=#{id}) and prop_key='assigned_to_id')
order by 6)")
  end
  
  def asignado_primer_estado(id)
    ActiveRecord::Base.connection.select_value("select u.firstname || ' ' || u.lastname from users u where cast(id as char(4))=(select old_value from journal_details where journal_id =(select min(journal_id) from journal_details where journal_id in(select id from journals where journalized_id=#{id}) and prop_key='assigned_to_id') and prop_key='assigned_to_id')")
  end
  
  def estado_ultimo_asignado(id)
    ActiveRecord::Base.connection.select_value("select name from issue_statuses where cast(id as char(4))=(select value from journal_details where journal_id =(select max(journal_id) from journal_details where journal_id in(select id from journals where journalized_id=#{id}) and prop_key='status_id') and prop_key='status_id')")
  end
 
  def fecha_fin_estado(id)
    ActiveRecord::Base.connection.select_value("select created_on from journals where id=(select min(journal_id) from journal_details where journal_id in(select id from journals where journalized_id=#{id}) and prop_key='assigned_to_id')")
  end
  
  def max_journal_status(id)
    ActiveRecord::Base.connection.select_value("select max(journal_id) from journal_details where journal_id in (select id from journals where journalized_id=#{id}) and (prop_key='status_id' or prop_key='assigned_to_id')")
  end
  #Fin de funciones
  
  def report_activities
    @project = Project.find params[:project_id]
    ###
    retrieve_query
    #    sort_init(@query.sort_criteria.empty? ? [['id', 'desc']] : @query.sort_criteria)
    #    sort_update(@query.sortable_columns)
    
    if @query.valid?
      @limit = Setting.issues_export_limit.to_i

      @issue_count = @query.issue_count
      @issue_pages = Paginator.new self, @issue_count, @limit, params['page']
      @offset ||= @issue_pages.current.offset
      @issues = @query.issues(:include => [:assigned_to, :tracker, :priority, :category, :fixed_version],
        #        :order => sort_clause,
        :offset => @offset,
        :limit => @limit)

      @iss = []
      @issues.each{|i|
        issue = Issue.find i.id
        @iss << issue
      }
      respond_to do |format|
        format.html { send_data(statuses_to_csv_activities(@iss, @project), :type => 'text/csv; header=present', :filename => 'export.csv')  }
      end      
    end
    ###
  end
  
  def statuses_to_csv_activities(issues, project = nil)
    #    ic = Iconv.new(l(:general_csv_encoding), 'UTF-8')
    encoding = l(:general_csv_encoding)
    export = FCSV.generate(:col_sep => l(:general_csv_separator)) do |csv|
      # csv header fields
      headers = [ "#",
        l(:field_status),
        l(:field_project),
        "Asignado A",
        "Fecha Inicio",
        "Fecha Fin/Actual",
        #        "Notas",
        #        "Nota Publica",
        l(:label_duration)
      ]
      #      csv << headers.collect {|c| begin; ic.iconv(c.to_s); rescue; c.to_s; end }
      csv << headers.collect {|c| Redmine::CodesetUtil.from_utf8(c.to_s, encoding) }
      issues.each{|issue|
        # csv lines
        @asignado_a=[]
        @asignado_a=asignado_mas(issue.id)
        @estado_a=[]
        @estado_a= estado_mas(issue.id)
        @issue = Issue.find(issue.id)
        @maximo_journal_estado_asignado=max_journal_status(issue.id)
        @valor_arreglo=@asignado_a.size
        @valor_arreglo_estado=@estado_a.size
        if @valor_arreglo>0
          @first=@asignado_a.first
          @asignado_a.each do |asignado|
            if @maximo_journal_estado_asignado==asignado["jdID"]
              @estado_final=estado_ultimo_asignado(asignado["issue_id"])
              fields_old = [asignado["issue_id"],
                @estado_final,
                asignado["nombre_proyecto"],
                asignado["new_state"],
                asignado["state_date_changed"].to_datetime.strftime("%m/%d/%Y %H:%M"),
                (Time.now).strftime("%m/%d/%Y %H:%M"),
                "#{distance_of_time_in_words Time.parse(asignado["state_date_changed"]), Time.now}"
              ]
              csv << fields_old.collect {|c| Redmine::CodesetUtil.from_utf8(c.to_s, encoding) } 
            end
            if asignado==@first and (asignado["fecha_inicio"].to_s.blank? and asignado["estado"].to_s.blank?)
              fields = [asignado["issue_id"],
                'Pendiente',
                asignado["nombre_proyecto"],
                asignado["old_state"],
                (@issue.created_on).strftime("%m/%d/%Y %H:%M"),
                asignado["state_date_changed"].to_datetime.strftime("%m/%d/%Y %H:%M"),
                "#{distance_of_time_in_words @issue.created_on, Time.parse(asignado["state_date_changed"])}"
              ]
              csv << fields.collect {|c| Redmine::CodesetUtil.from_utf8(c.to_s, encoding) }   
            else
              fields = [asignado["issue_id"],
                asignado["estado"],
                asignado["nombre_proyecto"],
                asignado["old_state"],
                asignado["fecha_inicio"].to_datetime.strftime("%m/%d/%Y %H:%M"),
                asignado["state_date_changed"].to_datetime.strftime("%m/%d/%Y %H:%M"),
                "#{distance_of_time_in_words Time.parse(asignado["fecha_inicio"]), Time.parse(asignado["state_date_changed"])}"
              ]
              csv << fields.collect {|c| Redmine::CodesetUtil.from_utf8(c.to_s, encoding) }   
            end
          end         
        end
        
        if  @valor_arreglo_estado>0
          @first_asignado=@estado_a.first
          @estado_a.each do |estado|
            @issue = Issue.find estado["issue_id"]
            if estado==@first_asignado and (estado["asignado"].blank? and estado["fecha_inicio"].blank?)
              @usuario_inicial=asignado_primer_estado(estado["issue_id"])
              @fecha_final_estado_inicial=fecha_fin_estado(estado["issue_id"])
              fields_inicio = [estado["issue_id"],
                estado["old_state"],
                estado["nombre_proyecto"],
                @usuario_inicial,
                (@issue.created_on).strftime("%m/%d/%Y %H:%M"),
                estado["state_date_changed"].to_datetime.strftime("%m/%d/%Y %H:%M"),
                "#{distance_of_time_in_words @issue.created_on, Time.parse(estado["state_date_changed"])}"
              ]             
              csv << fields_inicio.collect {|c| Redmine::CodesetUtil.from_utf8(c.to_s, encoding) } 
            else
              if @maximo_journal_estado_asignado==estado["jdID"]
                fields_old_estado = [estado["issue_id"],
                  estado["new_state"],
                  estado["nombre_proyecto"],
                  estado["asignado"],
                  estado["state_date_changed"].to_datetime.strftime("%m/%d/%Y %H:%M"),
                  (Time.now).strftime("%m/%d/%Y %H:%M"),
                  "#{distance_of_time_in_words Time.parse(estado["state_date_changed"]), Time.now}"
                ]
                csv << fields_old_estado.collect {|c| Redmine::CodesetUtil.from_utf8(c.to_s, encoding) } 
              end
              fields_estado = [estado["issue_id"],
                estado["old_state"],
                estado["nombre_proyecto"],
                estado["asignado"],
                estado["fecha_inicio"].to_datetime.strftime("%m/%d/%Y %H:%M"),
                estado["state_date_changed"].to_datetime.strftime("%m/%d/%Y %H:%M"),
                "#{distance_of_time_in_words Time.parse(estado["fecha_inicio"]), Time.parse(estado["state_date_changed"])}"
              ]
              csv << fields_estado.collect {|c| Redmine::CodesetUtil.from_utf8(c.to_s, encoding) }  
            end
          end
        end
      }
    end
    export
  end
  
  
  #Fin Requerimiento
end

