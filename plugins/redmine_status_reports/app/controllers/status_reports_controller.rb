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
  
  def statuses_to_csv(issues, project = nil)
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
        
        @status_by_id = by_id(issue.id)
        
        if @status_by_id.count>0
          @first=@status_by_id.first
          @status_by_id.each do |state|
            @issue = Issue.find state["issue_id"]
            
            s=@status_by_id.index(state)-1
            @jd=JournalDetail.find_by_journal_id_and_prop_key(state["jdID"],"assigned_to_id")
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
              fields = [state["issue_id"],
                state["old_state"],
                state["nombre_proyecto"],
                "#{@user.firstname} #{@user.lastname}",
                (@issue.created_on).strftime("%m/%d/%Y %H:%M"),
                (state["state_date_changed"]).to_datetime.strftime("%m/%d/%Y %H:%M"),
                #                state["notas"],
                #                state["visible"],
                "#{distance_of_time_in_words @issue.created_on, Time.parse(state["state_date_changed"])}"
              ]
            else
              if @jd_extra.nil?
                @user = @last
                if @user.nil?
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

              fields = [state["issue_id"],
                state["old_state"],
                state["nombre_proyecto"],
                "#{@user.firstname} #{@user.lastname}",
                ((@status_by_id.at(s))["state_date_changed"]).to_datetime.strftime("%m/%d/%Y %H:%M"),
                (state["state_date_changed"]).to_datetime.strftime("%m/%d/%Y %H:%M"),
                #                state["notas"],
                #                state["visible"],
                "#{distance_of_time_in_words Time.parse((@status_by_id.at(s))["state_date_changed"]), Time.parse(state["state_date_changed"])}"
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

          fields = [(@status_by_id.last)["issue_id"],
            (@status_by_id.last)["new_state"],
            (@status_by_id.last)["nombre_proyecto"],
            "#{@user.firstname} #{@user.lastname}",
            ((@status_by_id.last)["state_date_changed"]).to_datetime.strftime("%m/%d/%Y %H:%M"),
            (Time.now).strftime("%m/%d/%Y %H:%M"),
            #             (@status_by_id.last)["notas"],
            #             (@status_by_id.last)["visible"],
            "#{distance_of_time_in_words Time.parse((@status_by_id.last)["state_date_changed"]), Time.now}"
          ]
          #          csv << fields.collect {|c| begin; ic.iconv(c.to_s); rescue; c.to_s; end }
          csv << fields.collect {|c| Redmine::CodesetUtil.from_utf8(c.to_s, encoding) }
          #lista de journal details que no tienen estado
          @asignado_a=[]
          @asignado_a=by_mas_mas(issue.id)
          @fecha2=""
          @valor2=@asignado_a.size
          
          if @valor2.to_s=='1'
            @asignado_a.each do |param|
              @asignado_c=by_mas(issue.id,param)
              @asignado_c.each do |p1|
                @otros=p1["new_state_estado"]
                @usuario=otros_numero_usuario(param)
                @otro_asignado=User.find(@usuario)
                @fecha=p1["state_date_changed"]
                if p1["new_state_estado"].blank?
                  @otro=otro(issue.id)
                  @otro.each do |p2|
                    @otros='Pendiente'
                    @otro_asignado=p2["new_state"]
                  end
                end  
              
                @fecha2=fecha_anterior(p1["issue_id"], p1["id"])
                if @fecha2.blank?
                  @fecha2=@fecha
                end
              
                fields = [p1["issue_id"],
                  @otros,
                  p1["nombre_proyecto"],
                  @otro_asignado,
                  @fecha2.to_datetime.strftime("%m/%d/%Y %H:%M"),
                  @fecha.to_datetime.strftime("%m/%d/%Y %H:%M"),
                  "#{distance_of_time_in_words Time.parse(@fecha2), Time.parse(@fecha)}"
                ]
                #                csv << fields.collect {|c| begin; ic.iconv(c.to_s); rescue; c.to_s; end }
                csv << fields.collect {|c| Redmine::CodesetUtil.from_utf8(c.to_s, encoding) }
              end
            end
          else
            @asignado_a.each do |param|
              @asignado_c=by_mas(issue.id,param)
              @asignado_c.each do |p1|
                @otros=p1["new_state_estado"]
                @otro_asignado=p1["new_state"]
                @fecha=p1["state_date_changed"]
                if p1["new_state_estado"].blank?
                  @otro=otro(issue.id)
                  @otro.each do |p2|
                    @otros='Pendiente'
                    @otro_asignado=p2["new_state"]
                  end
                end  
              
                @fecha2=fecha_anterior(p1["issue_id"], p1["id"])
                if @fecha2.blank?
                  @fecha2=@fecha
                end
              
                fields = [p1["issue_id"],
                  @otros,
                  p1["nombre_proyecto"],
                  @otro_asignado,
                  @fecha2.to_datetime.strftime("%m/%d/%Y %H:%M"),
                  @fecha.to_datetime.strftime("%m/%d/%Y %H:%M"),
                  "#{distance_of_time_in_words Time.parse(@fecha2), Time.parse(@fecha)}"
                ]
                #                csv << fields.collect {|c| begin; ic.iconv(c.to_s); rescue; c.to_s; end }
                csv << fields.collect {|c| Redmine::CodesetUtil.from_utf8(c.to_s, encoding) }
              end
            end
          end
          #fin validacion
        else
          #Validacion asignado
          @asignado_a=[]
          @asignado_a=by_mas_mas(issue.id)
          @valor21=@asignado_a.size
          if @valor21.to_s=='1'
            @asignado_a.each do |param|
              @asignado_c=by_mas(issue.id,param)
              @asignado_c.each do |p1|
                @otros=p1["new_state_estado"]
                @usuario=otros_numero_usuario(param)
                @otro_asignado=User.find(@usuario)
                @fecha=p1["state_date_changed"]
                if p1["new_state_estado"].blank?
                  @otro=otro(issue.id)
                  @otro.each do |p2|
                    @otros='Pendiente'
                    @otro_asignado=p2["new_state"]
                  end
                end  
              
                @fecha2=fecha_anterior(p1["issue_id"], p1["id"])
                if @fecha2.blank?
                  @fecha2=@fecha
                end
              
                fields = [p1["issue_id"],
                  @otros,
                  p1["nombre_proyecto"],
                  @otro_asignado,
                  @fecha2.to_datetime.strftime("%m/%d/%Y %H:%M"),
                  @fecha.to_datetime.strftime("%m/%d/%Y %H:%M"),
                  "#{distance_of_time_in_words Time.parse(@fecha2), Time.parse(@fecha)}"
                ]
                #                csv << fields.collect {|c| begin; ic.iconv(c.to_s); rescue; c.to_s; end }
                csv << fields.collect {|c| Redmine::CodesetUtil.from_utf8(c.to_s, encoding) }
              end
            end
          else
            @asignado_a.each do |param|
              @asignado_c=by_mas(issue.id,param)
              @asignado_c.each do |p1|
                @otros=p1["new_state_estado"]
                @otro_asignado=p1["new_state"]
                @fecha=p1["state_date_changed"]
                if p1["new_state_estado"].blank?
                  @otro=otro(issue.id)
                  @otro.each do |p2|
                    @otros='Pendiente'
                    @otro_asignado=p2["new_state"]
                  end
                end  
              
                @fecha2=fecha_anterior(p1["issue_id"], p1["id"])
                if @fecha2.blank?
                  @fecha2=@fecha
                end
              
                fields = [p1["issue_id"],
                  @otros,
                  p1["nombre_proyecto"],
                  @otro_asignado,
                  @fecha2.to_datetime.strftime("%m/%d/%Y %H:%M"),
                  @fecha.to_datetime.strftime("%m/%d/%Y %H:%M"),
                  "#{distance_of_time_in_words Time.parse(@fecha2), Time.parse(@fecha)}"
                ]
                #                csv << fields.collect {|c| begin; ic.iconv(c.to_s); rescue; c.to_s; end }
                csv << fields.collect {|c| Redmine::CodesetUtil.from_utf8(c.to_s, encoding) }
              end
            end
          end          
          #fin validacion
          
          i=Issue.find issue.id
          if (i.assigned_to_id).blank?
            @user_name = ""
          else
            @user_name = (User.find i.assigned_to_id).name
          end
          @pro_i=nombre_proyecto_issues(i.id)
          fields = [i.id,
            (IssueStatus.find i.status_id).name,
            @pro_i,
            @user_name,
            (i.created_on).strftime("%m/%d/%Y %H:%M"),
            (Time.now).strftime("%m/%d/%Y %H:%M"),
            #            "",
            #            "",
            "#{distance_of_time_in_words i.created_on, Time.now}"
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

