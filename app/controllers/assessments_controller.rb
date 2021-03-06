require 'set'

class AssessmentsController < ApplicationController
  # Callback Methods
  before_action :set_competency, only: [:disclaimer, :take, :generate_report, :report]

  # Grouping user answers for each question into each stage
  DEVELOPED_ANSWERS = ["always", "often"]
  DEVELOPING_ANSWERS = ["sometimes"]
  EMERGINg_ANSWERS = ["rarely", "never"]

  # GET /assessments
  def index
    @active_competencies = Competency.active.alphabetical
  end

  # GET /assessments/disclaimer
  def disclaimer
  end

  # GET /assessments/send_email/:email
  def send_email
    @email = params[:email]
    @link = request.referer
    AssessmentMailer.send_assessment(@email,@link).deliver_now
    redirect_to @link
  end

  # POST /assessments/take
  def take
    if !params[:accept]
      flash[:error] = "You must accept the disclaimer first."
      redirect_to disclaimer_assessment_path
    end
    @questions = Question.for_competency(@competency.id)
  end

  # POST /assessments/report
  def generate_report
    questions = params[:questions]

    # Create a new hash where each question id is placed in the
    # corresponding stage based on user's answers
    @developing_stages = Hash.new
    @developing_stages[:developed] = Array.new
    @developing_stages[:developing] = Array.new
    @developing_stages[:emerging] = Array.new

    # Goes through each answer and place the respective question in the appropriate stage
    # For now we will ignore the does not apply category
    questions.each do |qid, answer_hash|
      answer = answer_hash[:answer]
      if DEVELOPED_ANSWERS.include? answer
          @developing_stages[:developed] << qid
      elsif DEVELOPING_ANSWERS.include? answer
          @developing_stages[:developing] << qid
      elsif EMERGINg_ANSWERS.include? answer
          @developing_stages[:emerging] << qid
      end
    end

    redirect_to report_assessment_path(competency_id: @competency, developing_stages: @developing_stages)
  end

  # GET /assessments/report
  def report
    @developing_stages = params[:developing_stages]
    @levels = Level.all.by_ranking
    @paradigms = Paradigm.all.by_ranking

    # Create a new hash with the appropriate indicators
    # (based on the question id's) in the corresponding stage
    @indicators_resources = Hash.new
    @indicators_resources["developed"] = Array.new
    @indicators_resources["developing"] = Array.new
    @indicators_resources["emerging"] = Array.new

    # Goes through each stage in the @developing_stages hash, generated by the generate_report action
    # and place the correct indicators in the @indicators_resources hash
    @developing_stages.each do |stage, qids|
      current_stage = Set.new

      # First map each of the question id's to the corresponding Question object
      questions = qids.map do |qid|
        Question.find(qid)
      end

      # Go through each Question object and generate a Set with all the unique indicators
      questions.each do |question|
        current_stage.merge(question.indicators)
      end

      # Convert the Set of indicators to an array and sort based on level
      # and place in the proper stage in the @indicators_resources hash
      @indicators_resources[stage] =
        current_stage.to_a.sort {|a,b| a.level.ranking <=> b.level.ranking}
    end

    if params[:printable] == "true"
      return render 'printable_report'
    end
  end


  private

  # Use callbacks to share common setup or constraints between actions.
  def set_competency
    @competency = Competency.find(params[:competency_id])
  end
end
