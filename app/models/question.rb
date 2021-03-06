class Question < ActiveRecord::Base
  has_many :answers
  has_many :options, dependent: :destroy
  accepts_nested_attributes_for :options, reject_if: proc { |attributes| attributes['name'].blank? }

  scope :single_multiple_questions, {:conditions => ['type in ( ? )', ['SingleAnswerQuestion', 'MultipleAnswerQuestion']]}

  after_update :save_options
 # validate :question_validate

  def question_validate
    errors[:base] << ("1_Question should not be blank") if name.blank?
    errors[:base] << ("1_Question type should not be blank") if type.blank?
  end

  def boolean=(boolean)
    options.destroy(options)
    options.reload
    options.build(boolean)
  end

  # Since it is STI we cannot directly assign type so use this method
  # example: we cannot assign like question.type=
  # use question.question_type=

  def question_type=(sType)
    self[:type]=sType
  end

  # We can't directly access the type attribute in question.
  # we can access that by @question[:type]

  def question_type
    self[:type]
  end

  def new_options=(new_options)
    debugger
    new_options.collect do |option|
      if option[:name]
        options.build(option) unless (option[:name].empty? or option[:name].delete(' ').eql?(''))
      end
    end
  end

  # This setter is only for multiple or single question options
  # Options will be in the string form seperated by "\n"
  def text_options=(text_options)
    text_options.strip.split("\r\n").collect(&:strip).uniq.collect { |name| options.build(:name => name) }
  end

  def existing_options=(existing_options)
    options.reject(&:new_record?).each do |option|
      attributes = existing_options[option.id.to_s]
      if attributes and !attributes[:name].empty? and !attributes[:name].delete(' ').eql?('')
        option.attributes = attributes
      else
        options.find(option.id).delete
      end
    end
  end

  # This method is called in the after_update
  def save_options
    debugger
    options.collect { |option| option.save }
  end


  # To get the answer from the params[:questionnaire_submission][:new_answer] hash
  def get_answer(new_questions) # new_questions = params[:questionnaire_submission][:new_answer]
    question_type = QUESTION_ANSWER_CONVERTER[self.class.to_s]
    if ['SingleAnswer', 'MultipleAnswer'].include?(question_type)
      answers = new_questions[question_type]
      answer = answers ? answers[self.id.to_s] : nil
      other_answers = new_questions[SINGLE_MULTIPLE_OTHER_MAP[self.class.to_s]]
      other_answer = other_answers ? other_answers[self.id.to_s] : nil
      if question_type == 'MultipleAnswer'
        [answer, other_answer]
      else
        (answer || other_answer || "").to_s
      end
    else
      (new_questions[question_type].values if new_questions[question_type]).to_s
    end
  end

end
