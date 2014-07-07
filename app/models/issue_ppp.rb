class IssuePpp < Issue
  
  attr_accessor :css_class, :current_user_id, :estimated_complete_date, :estimated_hours_user, :value
  def spent_hours_user
    sum = 0
    time_entries.each do |time_entry|
      if (time_entry.user_id == @current_user_id)
        sum += time_entry.hours
      end
    end
    @spent_hours_user ||= sum || 0
  end
  
  def self.getMyWork (current_user_id = User.current.id, filters = "", order = "", join = "")
    self.includes(:project).includes(:time_entries).includes(:custom_values).joins(join).where(:assigned_to_id => current_user_id, :closed_on => nil).where('status_id not in (5,6)').where('projects.status = 1').where(filters).order(order).preload(:project, :status, :tracker, :priority, :author, :assigned_to, :relations_to).to_a
  end
  
  def estimated_hours_user
    
    custom_values.each do |cv|
      if ( cv.customized_type == 'Issue' && cv.custom_field_id == 16 && cv.value != '' )
        return cv.value.to_f
      end
    end
    
    ( estimated_hours && estimated_hours != '' ) ? estimated_hours.to_f : 0
  end
  
  
  # Preloads total spent time for a collection of issues
  def self.load_total_spent_hours(issues, user=User.current)
    if issues.any?
      hours_by_issue_id = TimeEntry.where(:issue_id => issues.map(&:id)).group(:issue_id).sum(:hours)
      issues.each do |issue|
        issue.instance_variable_set "@total_spent_hours", (hours_by_issue_id[issue.id] || 0)
      end
    end
  end
end