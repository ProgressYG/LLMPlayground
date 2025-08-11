class UsageHistoryService
  def generate_report
    {
      statistics: overall_statistics,
      recent_prompts: recent_prompts_data,
      model_usage: model_usage_statistics
    }
  end

  private

  def overall_statistics
    {
      prompts_count: Prompt.count,
      executions_count: Execution.count,
      results_count: Result.count,
      templates_count: Template.count
    }
  end

  def recent_prompts_data
    Prompt.order(created_at: :desc)
          .limit(5)
          .map do |prompt|
            {
              id: prompt.id,
              model: prompt.selected_model,
              system_prompt: prompt.system_prompt,
              user_prompt: prompt.user_prompt,
              created_at: prompt.created_at.iso8601,
              parameters: prompt.parameters
            }
          end
  end

  def model_usage_statistics
    model_counts = Prompt.group(:selected_model)
                         .order('count_all DESC')
                         .count

    model_counts.map do |model, count|
      {
        model: model,
        count: count
      }
    end
  end
end