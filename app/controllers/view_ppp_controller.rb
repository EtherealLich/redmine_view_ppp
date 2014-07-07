class ViewPppController < ApplicationController
  unloadable

  attr_accessor :project_end_time, :current_user_id, :project_load_coef, :user_load_coef
  
  # Идентификаторы отделов
  @@user_groups = {
    :orppo => 55,
    :op => 106,
    :orbd => 166,
    :osz => 175,
    :oro => 206,
    :ot => 226,
    :orias => 264,
    :orss=> 269,
    :er => 339,
    :design => 343
  }
  
  # Коэффициент загрузки пока у пользователя есть проекты
  @@project_load_coef = 0.5
  
  # Коэффициент загрузки когла у пользователя нет проектов
  @@user_load_coef = 1
  
  # Группа менеджеров ДРПО
  @@drpo_managers = 270
  
  # Группа руководства
  @@directors = 205
    
  def index
    if (!params[:user_id] || params[:user_id] == 'index')
      @current_user_id = User.current.id
    else
      @current_user_id = params[:user_id]
    end
    @groups = User.find(User.current.id).groups.map(&:id)
    @group_manager = @groups.include? @@drpo_managers
    @director = @groups.include? @@directors
    @groups = @groups - [@@drpo_managers, @@directors, 344]
    
    if (@director)
      @group_users = User.where(:status => 1).compact.sort.to_a.uniq
    elsif
      @group_users = User.joins("left join groups_users on users.id = groups_users.user_id").where(groups_users: { :group_id => @groups }).where(:status => 1).compact.sort.to_a.uniq
    end

    if ( !@group_users.map(&:id).include?(@current_user_id.to_i) )
      @current_user_id = User.current.id
    end

    if ( @groups.include?(@@user_groups[:op]) )
      join = " left join custom_values cv on cv.customized_type = 'Issue' and cv.custom_field_id = 15 and issues.id = cv.customized_id"
    elsif ( @groups.include?(@@user_groups[:osz]) || @groups.include?(@@user_groups[:orbd]) )
      join = " left join custom_values cv on cv.customized_type = 'Issue' and cv.custom_field_id = 19 and issues.id = cv.customized_id"
    elsif ( @groups.include?(@@user_groups[:ot]) )
      join = " left join custom_values cv on cv.customized_type = 'Issue' and cv.custom_field_id = 18 and issues.id = cv.customized_id"
    else
      join = " left join custom_values cv on cv.customized_type = 'Issue' and cv.custom_field_id = 16 and issues.id = cv.customized_id"
    end

    @issues1 = IssuePpp.getMyWork @current_user_id, 
      " issues.project_id in (
			select p.id from projects p
			inner join custom_values cv on p.id = cv.customized_id and cv.custom_field_id = 20 and cv.value = 1
			where status = 1
		) and issues.id in (SELECT customized_id FROM custom_values where customized_type = 'Issue' and custom_field_id = 13 and value = 1)",
      "issues.due_date asc, issues.updated_on asc",
      join
    IssuePpp.load_visible_spent_hours(@issues1)
    IssuePpp.load_total_spent_hours(@issues1)

    @issues1.each do |issue|
      issue.current_user_id = @current_user_id
      issue.css_class = ""
     
      if ( issue.due_date && issue.due_date <= Date.today.next_week.advance(:days => -1) ) 
          issue.css_class += ' this_week'
      end
      
      if ( issue.due_date && issue.due_date < Date.today )
          issue.css_class += ' overdue'
      end

      # Ищем последнюю дату завершения проектных задач
      if ( issue.due_date )
        if (@project_end_time)
          if ( issue.due_date > @project_end_time )
            @project_end_time = issue.due_date;
          end
        else
          @project_end_time = issue.due_date;
        end
      end
    end
    
    if (!@project_end_time)
        # Если не задана дата окончания проектных задач, считаем что они закончены в начале 2014 года, а почему бы нет
        @project_end_time = Date.parse('204-01-01');
    else
        # Если задана дата окончания проекта, считаем что внепроектная работа начинается с утра следующего дня
        @project_end_time = @project_end_time.next_day;
    end
    
    order = "case when nullif(cv.value, '') is not null then cv.value*1 else case when nullif(issues.estimated_hours, '') is not null then issues.estimated_hours*1 else 10000 end end asc,"
    
    @issues2 = IssuePpp.getMyWork @current_user_id,
      " issues.project_id in (
			select p.id from projects p
			inner join custom_values cv on p.id = cv.customized_id and cv.custom_field_id = 20 and cv.value = 1
			where status = 1
      ) and issues.id not in (SELECT customized_id FROM custom_values where customized_type = 'Issue' and custom_field_id = 13 and value = 1)",
      "case when issues.priority_id = 7 then 1 else 0 end desc, " + order + " coalesce(issues.due_date, '2030-01-01') asc, issues.created_on asc",
      join
    IssuePpp.load_visible_spent_hours(@issues2)
    IssuePpp.load_total_spent_hours(@issues2)
    
    prev_issue = nil
    
    @issues2.each do |issue|
      issue.current_user_id = @current_user_id
      issue.css_class = ""

      if ( issue.due_date && issue.due_date < Date.today )
        issue.css_class += ' overdue'
      end
      
      if ( issue.priority_id && issue.priority_id == 7 )
        issue.css_class += ' immediate'
      end
      
      if ( issue.estimated_hours_user && issue.estimated_hours_user > 0 )
        # сколько минут осталось на задачу, из запланированного времени вычитаем уже потраченное по пользователю
        minutes_left = (issue.estimated_hours_user - issue.spent_hours_user)*60 
        minutes_left = (minutes_left > 0) ? minutes_left : 0 # если уже потрачено больше чем запланировано, то считаем 0 минут

        if ( prev_issue)
          # если есть предыдущая задача то отсчитываем от ее конца
          issue.estimated_complete_date = add_worktime(minutes_left, prev_issue.estimated_complete_date);
        else
          # иначе считаем от текущего времени
          issue.estimated_complete_date = add_worktime(minutes_left);
        end
        prev_issue = issue
      else
        # если нет оценки времени на задачу, то мы не можем посчитать дату выполнения
        issue.estimated_complete_date = nil;
      end
    end
    
    @issues3 = IssuePpp.getMyWork @current_user_id,
      " issues.project_id not in (
			select p.id from projects p
			inner join custom_values cv on p.id = cv.customized_id and cv.custom_field_id = 20 and cv.value = 1
			where status = 1
      ) ",
      "case when issues.priority_id = 7 then '1970-01-01' else coalesce(issues.due_date, '2030-01-01') end asc, issues.updated_on asc",
      join
    IssuePpp.load_visible_spent_hours(@issues3)
    IssuePpp.load_total_spent_hours(@issues3)
    
    @issues3.each do |issue|
      issue.current_user_id = @current_user_id
      issue.css_class = ""

      if ( issue.due_date && issue.due_date < Date.today )
        issue.css_class += ' overdue'
      end
      
      if ( issue.priority_id && issue.priority_id == 7 )
        issue.css_class += ' immediate'
      end
    end
            
    render "show"
  end
  
  def add_worktime minutesToAdd, timestamp = nil
    if ( !timestamp )
        timestamp = Time.new(Date.today.year, Date.today.month, Date.today.day, 9, 0, 0, 0)
    end
    
    # Даты начала и конца рабочего дня
    dayStart = 9;
    dayEnd = 18;
    
    lunchHour = 12;
    
    minutesToAdd.to_i.times do
      if ( Time.parse(@project_end_time.to_s) > timestamp )
        # Если у нас есть активный проект, то берем проектный коэффициент загрузки
        coef = @@project_load_coef;
      else
        # иначе берем коэффициент загрузки по пользователю
        coef = @@user_load_coef;
      end
      
      timestamp += 60 * coef
      
      # Если время вышло за пределы рабочего
      if ( timestamp.hour >= dayEnd || timestamp.hour < dayStart )
        # После конца рабочего дня
        if (timestamp.hour >= dayEnd)
          # Перескакиваем на начало следующего рабочего дня
          timestamp += 3600 * ((24 - timestamp.hour) + dayStart);
        # До начала рабочего дня
        else
          # Перескакиваем на начало рабочего дня
          timestamp += 3600 * (dayStart - timestamp.hour);
        end
      end

      # Если время обеда
      if ( timestamp.hour == lunchHour )
          # Перескакиваем на послеобеденное время
          timestamp += 60 * (60 - timestamp.min);
      end

      # Пока это выходной или праздник, прыгаем вперед
      while ( timestamp.saturday? || timestamp.sunday? )
          # Переходим на понедельник
          timestamp += 3600 * 24;
      end
    end
    
    timestamp
  end

end
