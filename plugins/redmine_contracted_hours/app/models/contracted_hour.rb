class ContractedHour < ActiveRecord::Base
  class StatementInvalid < ::ActiveRecord::StatementInvalid
  end
  unloadable
  
  class_attribute :queried_class
  belongs_to :project
  serialize :filters
  self.queried_class = Issue
  
  # Return a hash of available filters
  # TODO 217
  def available_filters
    unless @available_filters
      initialize_available_filters
      @available_filters.each do |field, options|
        options[:name] ||= l(options[:label] || "field_#{field}".gsub(/_id$/, ''))
      end
    end
    @available_filters
  end
  
  def all_projects
    @all_projects ||= Project.visible.all
  end
  
  # Adds an available filter
  def add_available_filter(field, options)
    @available_filters ||= ActiveSupport::OrderedHash.new
    @available_filters[field] = options
    @available_filters
  end
  
  def all_projects_values
    return @all_projects_values if @all_projects_values

    values = []
    Project.project_tree(all_projects) do |p, level|
      prefix = (level > 0 ? ('--' * level + ' ') : '')
      values << ["#{prefix}#{p.name}", p.id.to_s]
    end
    @all_projects_values = values
  end
  
  def trackers
    @trackers ||= project.nil? ? Tracker.sorted.all : project.rolled_up_trackers
  end
  
  # Adds available filters
  def initialize_available_filters
    principals = []
    subprojects = []
    versions = []
    categories = []
    issue_custom_fields = []
    watcher_values = []
    route_values = []
    #principals << ["<< #{l(:label_me)} >>", "me"] if User.current.logged?
    watcher_values << ["<< #{l(:label_me)} >>", User.current.id]
    watcher_values << ["<< #{l(:label_none)} >>", "*"]

    if project
      principals += project.principals.sort
      unless project.leaf?
        subprojects = project.descendants.visible.all
        principals += Principal.member_of(subprojects)
      end
      versions = project.shared_versions.all
      categories = project.issue_categories.all
      issue_custom_fields = project.all_issue_custom_fields
      watcher_values += project.users.sort.collect{|s| [s.name, s.id.to_s] }
      route_values = project.users
      route_values.reject! { |u| !u.allowed_to_unless_admin?(:client_automatic_routing,@project)  }
      route_values = route_values.sort.collect{|s| [s.name, s.id.to_s] }
      route_values << ["<< #{l(:label_me)} >>", "me"]
    else
      if all_projects.any?
        projects = all_projects.collect(&:id)
        principals += Principal.active.find(:all, :conditions => ["#{User.table_name}.id IN (SELECT DISTINCT user_id FROM members WHERE project_id IN (?))",projects ]).sort
        watcher_values += User.active.find(:all, :conditions => ["#{User.table_name}.id IN (SELECT DISTINCT user_id FROM members WHERE project_id IN (?))", projects ]).sort
        route_values += User.active.find(:all, :conditions => ["#{User.table_name}.id IN (SELECT DISTINCT  route_id as user_id FROM issues WHERE project_id IN (?))", projects ]).sort
      end
      versions = Version.visible.where(:sharing => 'system').all
      issue_custom_fields = IssueCustomField.where(:is_for_all => true)
    end
    principals.uniq!
    principals.sort!
    users = principals.select {|p| p.is_a?(User)}

    add_available_filter "status_id",
      :type => :list_status, :values => IssueStatus.sorted.collect{|s| [s.name, s.id.to_s] }

    if project.nil?
      project_values = []
      if User.current.logged? && User.current.memberships.any?
        project_values << ["<< #{l(:label_my_projects).downcase} >>", "mine"]
      end
      project_values += all_projects_values
      add_available_filter("project_id",
        :type => :list, :values => project_values
      ) unless project_values.empty?
    end

    add_available_filter "tracker_id",
      :type => :list, :values => trackers.collect{|s| [s.name, s.id.to_s] }
    add_available_filter "priority_id",
      :type => :list, :values => IssuePriority.all.collect{|s| [s.name, s.id.to_s] }

    author_values = []
    author_values << ["<< #{l(:label_me)} >>", "me"] if User.current.logged?
    author_values += users.collect{|s| [s.name, s.id.to_s] }
    add_available_filter("author_id",
      :type => :list, :values => author_values
    ) unless author_values.empty?

    assigned_to_values = []
    assigned_to_values << ["<< #{l(:label_me)} >>", "me"] if User.current.logged?
    assigned_to_values += (Setting.issue_group_assignment? ?
        principals : users).collect{|s| [s.name, s.id.to_s] }
    add_available_filter("assigned_to_id",
      :type => :list_optional, :values => assigned_to_values
    ) unless assigned_to_values.empty?

    group_values = Group.all.collect {|g| [g.name, g.id.to_s] }
    add_available_filter("member_of_group",
      :type => :list_optional, :values => group_values
    ) unless group_values.empty?

    role_values = Role.givable.collect {|r| [r.name, r.id.to_s] }
    add_available_filter("assigned_to_role",
      :type => :list_optional, :values => role_values
    ) unless role_values.empty?

    if versions.any?
      add_available_filter "fixed_version_id",
        :type => :list_optional,
        :values => versions.sort.collect{|s| ["#{s.project.name} - #{s.name}", s.id.to_s] }
    end

    if categories.any?
      add_available_filter "category_id",
        :type => :list_optional,
        :values => categories.collect{|s| [s.name, s.id.to_s] }
    end

    add_available_filter "subject", :type => :text
    add_available_filter "created_on", :type => :date_past
    add_available_filter "updated_on", :type => :date_past
    add_available_filter "closed_on", :type => :date_past
    add_available_filter "start_date", :type => :date
    add_available_filter "due_date", :type => :date
    add_available_filter "estimated_hours", :type => :float
    add_available_filter "done_ratio", :type => :integer

    if User.current.allowed_to?(:set_issues_private, nil, :global => true) ||
        User.current.allowed_to?(:set_own_issues_private, nil, :global => true)
      add_available_filter "is_private",
        :type => :list,
        :values => [[l(:general_text_yes), "1"], [l(:general_text_no), "0"]]
    end

    if User.current.logged?
      add_available_filter "watcher_id",
        :type => :list, :values => watcher_values unless watcher_values.empty?
    end
    
    if User.current.logged?
      add_available_filter "route_id",
        :type => :list, :values => route_values unless route_values.empty?
    end
    
    #Agregar el filtro para peticiones privadas
    private_options = []
    private_options << [l(:general_text_Yes), "1"]
    private_options << [l(:general_text_No), "0"]
    add_available_filter "is_private",
      :type => :list, :values => private_options unless private_options.empty?

    if subprojects.any?
      add_available_filter "subproject_id",
        :type => :list_subprojects,
        :values => subprojects.collect{|s| [s.name, s.id.to_s] }
    end

    add_custom_fields_filters(issue_custom_fields)

    IssueRelation::TYPES.each do |relation_type, options|
      add_available_filter relation_type, :type => :relation, :label => options[:name]
    end

    Tracker.disabled_core_fields(trackers).each {|field|
      delete_available_filter field
    }
  end
  
  # Builds the query from the given params
  def build_from_params(params)
    if params[:fields] || params[:f]
      self.filters = {}
      add_filters(params[:fields] || params[:f], params[:operators] || params[:op], params[:values] || params[:v])
    else
      available_filters.keys.each do |field|
        add_short_filter(field, params[field]) if params[field]
      end
    end
    self
  end
  
  # Returns the issue count
  def issue_count
    Issue.joins(:project).where(statement).count
  rescue ::ActiveRecord::StatementInvalid => e
    raise StatementInvalid.new(e.message)
  end
  
  # Returns the issues
  def issues(options={})
    scope = Issue.joins(:project).where(statement)
    issues = scope.all
    issues
  rescue ::ActiveRecord::StatementInvalid => e
    raise StatementInvalid.new(e.message)
  end
  
  # Returns the issues ids
  def issue_ids(options={})
    # Issue.
    Issue.visible.
      joins(:status, :project).
      where(statement).
      find_ids
  rescue ::ActiveRecord::StatementInvalid => e
    raise StatementInvalid.new(e.message)
  end
  
  #devuelve todo el objeto issue
  def entire_issues
    Issue.find(:all,:conditions => ["id in (?)", issue_ids ])
  end
  
  def available_hours
    time = Time.new
    # suma de horas de tiempo dedicado

    @valor=0
    if !issue_ids.nil?
      @valor=self.hours.to_f - TimeEntry.select("hours").where(:issue_id => issue_ids, :tyear => time.year, :tmonth => time.month).map(&:hours).inject(0, :+)
    end
    return  @valor
  end
  
  def month_time_entries(issue)
    time = Time.new
    TimeEntry.select("hours").where(:issue_id => issue, :tyear => time.year, :tmonth => time.month).map(&:hours).inject(0, :+)
  end
  
  def related_hours
    time = Time.new
    # suma de horas de tiempo dedicado
    @total_hours= 0+ TimeEntry.select("hours").where(:issue_id => issue_ids, :tyear => time.year, :tmonth => time.month).map(&:hours).inject(0, :+)
    return @total_hours
  end
  
  def clear_estimated_hour(caso)
    @tiempo_facturar = 0
    if !caso.estimated_hours.nil? and caso.estimated_hours > 0.00
     @tiempo_facturar= caso.estimated_hours
    else
     @tiempo_facturar= 0.0 
    end
    return @tiempo_facturar
  end
 
  
  def porcentaje_horas(contratadas, disponibles)
    porcentaje = (disponibles.to_f * 100)/contratadas.to_f
    if (porcentaje > 0)
      return porcentaje.round
    else
      return 0
    end
  end
  
  def statement
    # filters clauses
    filters_clauses = []
  
    filters.each_key do |field|

      next if field == "subproject_id"
      v = values_for(field).clone
      next unless v and !v.empty?
      operator = operator_for(field)

      # "me" value subsitution
      if %w(assigned_to_id author_id user_id watcher_id).include?(field)
        if v.delete("me")
          if User.current.logged?
            v.push(User.current.id.to_s)
            v += User.current.group_ids.map(&:to_s) if field == 'assigned_to_id'
          else
            v.push("0")
          end
        end
      end
      
      if field == 'project_id'
        if v.delete('mine')
          v += User.current.memberships.map(&:project_id).map(&:to_s)
        end
      end

      if field =~ /cf_(\d+)$/
        # custom field
        filters_clauses << sql_for_custom_field(field, operator, v, $1)
      elsif respond_to?("sql_for_#{field}_field")
        # specific statement
        filters_clauses << send("sql_for_#{field}_field", field, operator, v)
      else
        # regular field
        filters_clauses << '(' + sql_for_field(field, operator, v, queried_table_name, field) + ')'
      end
    end if filters and valid?

    filters_clauses << project_statement
    filters_clauses.reject!(&:blank?)

    filters_clauses.any? ? filters_clauses.join(' AND ') : nil
  end

  def values_for(field)
    has_filter?(field) ? filters[field][:values] : nil
  end
  
  def has_filter?(field)
    filters and filters[field]
  end
  
  def operator_for(field)
    has_filter?(field) ? filters[field][:operator] : nil
  end
  
  def queried_table_name
    @queried_table_name ||= self.class.queried_class.table_name
  end
  
  def type_for(field)
    available_filters[field][:type] if available_filters.has_key?(field)
  end
  
  def project_statement
    project_clauses = []
    if project && !project.descendants.active.empty?
      ids = [project.id]
      if has_filter?("subproject_id")
        case operator_for("subproject_id")
        when '='
          # include the selected subprojects
          ids += values_for("subproject_id").each(&:to_i)
        when '!*'
          # main project only
        else
          # all subprojects
          ids += project.descendants.collect(&:id)
        end
      elsif Setting.display_subprojects_issues?
        ids += project.descendants.collect(&:id)
      end
      project_clauses << "#{Project.table_name}.id IN (%s)" % ids.join(',')
    elsif project
      project_clauses << "#{Project.table_name}.id = %d" % project.id
    end
    project_clauses.any? ? project_clauses.join(' AND ') : nil
  end
  
  # Add multiple filters using +add_filter+
  def add_filters(fields, operators, values)
    if fields.is_a?(Array) && operators.is_a?(Hash) && (values.nil? || values.is_a?(Hash))
      fields.each do |field|
        add_filter(field, operators[field], values && values[field])
      end
    end
  end
  
  def add_filter(field, operator, values=nil)
    # values must be an array
    return unless values.nil? || values.is_a?(Array)
    # check if field is defined as an available filter
    if available_filters.has_key? field
      filter_options = available_filters[field]
      filters[field] = {:operator => operator, :values => (values || [''])}
    end
  end
  
  # Returns a representation of the available filters for JSON serialization
  def available_filters_as_json
    json = {}
    available_filters.each do |field, options|
      json[field] = options.slice(:type, :name, :values).stringify_keys
    end
    json
  end
  
  def contracted_hour_color(available_hours, contracted_hour)
    if available_hours/contracted_hour.hours.to_f > 0.5 
      color = "green" 
    elsif available_hours <= 0
      color = "red" 
    elsif available_hours/contracted_hour.hours.to_f <= 0.5
      color = "orange" 
    end
    color
  end
  
  private
  
  # Adds a filter for the given custom field
  def add_custom_field_filter(field, assoc=nil)
    options = field.format.query_filter_options(field, self)
    if field.format.target_class && field.format.target_class <= User
      if options[:values].is_a?(Array) && User.current.logged?
        options[:values].unshift ["<< #{l(:label_me)} >>", "me"]
      end
    end

    filter_id = "cf_#{field.id}"
    filter_name = field.name
    if assoc.present?
      filter_id = "#{assoc}.#{filter_id}"
      filter_name = l("label_attribute_of_#{assoc}", :name => filter_name)
    end
    add_available_filter filter_id, options.merge({
        :name => filter_name,
        :field => field
      })
  end
  
  # Helper method to generate the WHERE sql for a +field+, +operator+ and a +value+
  
  def sql_for_custom_field(field, operator, value, custom_field_id)
    db_table = CustomValue.table_name
    db_field = 'value'
    filter = @available_filters[field]
    return nil unless filter
    if filter[:field].format.target_class && filter[:field].format.target_class <= User
      if value.delete('me')
        value.push User.current.id.to_s
      end
    end
    not_in = nil
    if operator == '!'
      # Makes ! operator work for custom fields with multiple values
      operator = '='
      not_in = 'NOT'
    end
    customized_key = "id"
    customized_class = queried_class
    if field =~ /^(.+)\.cf_/
      assoc = $1
      customized_key = "#{assoc}_id"
      customized_class = queried_class.reflect_on_association(assoc.to_sym).klass.base_class rescue nil
      raise "Unknown #{queried_class.name} association #{assoc}" unless customized_class
    end
    where = sql_for_field(field, operator, value, db_table, db_field, true)
    if operator =~ /[<>]/
      where = "(#{where}) AND #{db_table}.#{db_field} <> ''"
    end
    "#{queried_table_name}.#{customized_key} #{not_in} IN (" +
      "SELECT #{customized_class.table_name}.id FROM #{customized_class.table_name}" +
      " LEFT OUTER JOIN #{db_table} ON #{db_table}.customized_type='#{customized_class}' AND #{db_table}.customized_id=#{customized_class.table_name}.id AND #{db_table}.custom_field_id=#{custom_field_id}" +
      " WHERE (#{where}) AND (#{filter[:field].visibility_by_project_condition}))"
  end
  
  def sql_for_field(field, operator, value, db_table, db_field, is_custom_filter=false)
    sql = ''
    case operator
    when "="
      if value.any?
        case type_for(field)
        when :date, :date_past
          sql = date_clause(db_table, db_field, parse_date(value.first), parse_date(value.first))
        when :integer
          if is_custom_filter
            sql = "(#{db_table}.#{db_field} <> '' AND CAST(CASE #{db_table}.#{db_field} WHEN '' THEN '0' ELSE #{db_table}.#{db_field} END AS decimal(30,3)) = #{value.first.to_i})"
          else
            sql = "#{db_table}.#{db_field} = #{value.first.to_i}"
          end
        when :float
          if is_custom_filter
            sql = "(#{db_table}.#{db_field} <> '' AND CAST(CASE #{db_table}.#{db_field} WHEN '' THEN '0' ELSE #{db_table}.#{db_field} END AS decimal(30,3)) BETWEEN #{value.first.to_f - 1e-5} AND #{value.first.to_f + 1e-5})"
          else
            sql = "#{db_table}.#{db_field} BETWEEN #{value.first.to_f - 1e-5} AND #{value.first.to_f + 1e-5}"
          end
        else
          sql = "#{db_table}.#{db_field} IN (" + value.collect{|val| "'#{connection.quote_string(val)}'"}.join(",") + ")"
        end
      else
        # IN an empty set
        sql = "1=0"
      end
    when "!"
      if value.any?
        sql = "(#{db_table}.#{db_field} IS NULL OR #{db_table}.#{db_field} NOT IN (" + value.collect{|val| "'#{connection.quote_string(val)}'"}.join(",") + "))"
      else
        # NOT IN an empty set
        sql = "1=1"
      end
    when "!*"
      sql = "#{db_table}.#{db_field} IS NULL"
      sql << " OR #{db_table}.#{db_field} = ''" if is_custom_filter
    when "*"
      sql = "#{db_table}.#{db_field} IS NOT NULL"
      sql << " AND #{db_table}.#{db_field} <> ''" if is_custom_filter
    when ">="
      if [:date, :date_past].include?(type_for(field))
        sql = date_clause(db_table, db_field, parse_date(value.first), nil)
      else
        if is_custom_filter
          sql = "(#{db_table}.#{db_field} <> '' AND CAST(CASE #{db_table}.#{db_field} WHEN '' THEN '0' ELSE #{db_table}.#{db_field} END AS decimal(30,3)) >= #{value.first.to_f})"
        else
          sql = "#{db_table}.#{db_field} >= #{value.first.to_f}"
        end
      end
    when "<="
      if [:date, :date_past].include?(type_for(field))
        sql = date_clause(db_table, db_field, nil, parse_date(value.first))
      else
        if is_custom_filter
          sql = "(#{db_table}.#{db_field} <> '' AND CAST(CASE #{db_table}.#{db_field} WHEN '' THEN '0' ELSE #{db_table}.#{db_field} END AS decimal(30,3)) <= #{value.first.to_f})"
        else
          sql = "#{db_table}.#{db_field} <= #{value.first.to_f}"
        end
      end
    when "><"
      if [:date, :date_past].include?(type_for(field))
        sql = date_clause(db_table, db_field, parse_date(value[0]), parse_date(value[1]))
      else
        if is_custom_filter
          sql = "(#{db_table}.#{db_field} <> '' AND CAST(CASE #{db_table}.#{db_field} WHEN '' THEN '0' ELSE #{db_table}.#{db_field} END AS decimal(30,3)) BETWEEN #{value[0].to_f} AND #{value[1].to_f})"
        else
          sql = "#{db_table}.#{db_field} BETWEEN #{value[0].to_f} AND #{value[1].to_f}"
        end
      end
    when "o"
      sql = "#{queried_table_name}.status_id IN (SELECT id FROM #{IssueStatus.table_name} WHERE is_closed=#{connection.quoted_false})" if field == "status_id"
    when "c"
      sql = "#{queried_table_name}.status_id IN (SELECT id FROM #{IssueStatus.table_name} WHERE is_closed=#{connection.quoted_true})" if field == "status_id"
    when "><t-"
      # between today - n days and today
      sql = relative_date_clause(db_table, db_field, - value.first.to_i, 0)
    when ">t-"
      # >= today - n days
      sql = relative_date_clause(db_table, db_field, - value.first.to_i, nil)
    when "<t-"
      # <= today - n days
      sql = relative_date_clause(db_table, db_field, nil, - value.first.to_i)
    when "t-"
      # = n days in past
      sql = relative_date_clause(db_table, db_field, - value.first.to_i, - value.first.to_i)
    when "><t+"
      # between today and today + n days
      sql = relative_date_clause(db_table, db_field, 0, value.first.to_i)
    when ">t+"
      # >= today + n days
      sql = relative_date_clause(db_table, db_field, value.first.to_i, nil)
    when "<t+"
      # <= today + n days
      sql = relative_date_clause(db_table, db_field, nil, value.first.to_i)
    when "t+"
      # = today + n days
      sql = relative_date_clause(db_table, db_field, value.first.to_i, value.first.to_i)
    when "t"
      # = today
      sql = relative_date_clause(db_table, db_field, 0, 0)
    when "ld"
      # = yesterday
      sql = relative_date_clause(db_table, db_field, -1, -1)
    when "w"
      # = this week
      first_day_of_week = l(:general_first_day_of_week).to_i
      day_of_week = Date.today.cwday
      days_ago = (day_of_week >= first_day_of_week ? day_of_week - first_day_of_week : day_of_week + 7 - first_day_of_week)
      sql = relative_date_clause(db_table, db_field, - days_ago, - days_ago + 6)
    when "lw"
      # = last week
      first_day_of_week = l(:general_first_day_of_week).to_i
      day_of_week = Date.today.cwday
      days_ago = (day_of_week >= first_day_of_week ? day_of_week - first_day_of_week : day_of_week + 7 - first_day_of_week)
      sql = relative_date_clause(db_table, db_field, - days_ago - 7, - days_ago - 1)
    when "l2w"
      # = last 2 weeks
      first_day_of_week = l(:general_first_day_of_week).to_i
      day_of_week = Date.today.cwday
      days_ago = (day_of_week >= first_day_of_week ? day_of_week - first_day_of_week : day_of_week + 7 - first_day_of_week)
      sql = relative_date_clause(db_table, db_field, - days_ago - 14, - days_ago - 1)
    when "m"
      # = this month
      date = Date.today
      sql = date_clause(db_table, db_field, date.beginning_of_month, date.end_of_month)
    when "lm"
      # = last month
      date = Date.today.prev_month
      sql = date_clause(db_table, db_field, date.beginning_of_month, date.end_of_month)
    when "y"
      # = this year
      date = Date.today
      sql = date_clause(db_table, db_field, date.beginning_of_year, date.end_of_year)
    when "~"
      sql = "LOWER(#{db_table}.#{db_field}) LIKE '%#{connection.quote_string(value.first.to_s.downcase)}%'"
    when "!~"
      sql = "LOWER(#{db_table}.#{db_field}) NOT LIKE '%#{connection.quote_string(value.first.to_s.downcase)}%'"
    else
      raise "Unknown query operator #{operator}"
    end

    return sql
  end
  
  # Returns a SQL clause for a date or datetime field using relative dates.
  def relative_date_clause(table, field, days_from, days_to)
    date_clause(table, field, (days_from ? Date.today + days_from : nil), (days_to ? Date.today + days_to : nil))
  end
  
  # Returns a Date or Time from the given filter value
  def parse_date(arg)
    if arg.to_s =~ /\A\d{4}-\d{2}-\d{2}T/
      Time.parse(arg) rescue nil
    else
      Date.parse(arg) rescue nil
    end
  end
  
  # Returns a SQL clause for a date or datetime field.
  def date_clause(table, field, from, to)
    s = []
    if from
      if from.is_a?(Date)
        from = Time.local(from.year, from.month, from.day).yesterday.end_of_day
      else
        from = from - 1 # second
      end
      if self.class.default_timezone == :utc
        from = from.utc
      end
      s << ("#{table}.#{field} > '%s'" % [connection.quoted_date(from)])
    end
    if to
      if to.is_a?(Date)
        to = Time.local(to.year, to.month, to.day).end_of_day
      end
      if self.class.default_timezone == :utc
        to = to.utc
      end
      s << ("#{table}.#{field} <= '%s'" % [connection.quoted_date(to)])
    end
    s.join(' AND ')
  end

  
  # Adds filters for the given custom fields scope
  def add_custom_fields_filters(scope, assoc=nil)
    scope.visible.where(:is_filter => true).sorted.each do |field|
      add_custom_field_filter(field, assoc)
    end
  end
end
