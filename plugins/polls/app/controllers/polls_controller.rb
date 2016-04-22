class PollsController < ApplicationController
  unloadable

  def index
    @remote = false
    @issue = Issue.find(params[:issue_id])
    @project_id = params[:project_id]
  end
 
  def create
    poll_answerses = params[:poll_answers]
    issue_param = params[:issue_id]
    polls_count = params[:polls_count]
    issue_id = issue_param.keys.first
    
    if poll_answerses == nil || (poll_answerses != nil && polls_count.to_i != poll_answerses.count.to_i)
      flash[:error] = "Debe responder todas las preguntas, gracias."
      redirect_to :controller => "polls", :action => "index", :issue_id => issue_id, :project_id => params[:project_id]
      return
    end
    
    if poll_answerses != nil
      poll_answerses.keys.each{ |poll_id|
        @poll_answers = PollAnswers.new
        @poll_answers.poll_id = poll_id
        poll_answer = poll_answerses[poll_id]
      
        if poll_answer.is_a?(Hash)
          @poll_answers.answer_open = poll_answer[:answer_open]
        else
          @poll_answers.answer_id = poll_answerses[poll_id]
        end  
      
        @poll_answers.issue_id = issue_id.to_i
        @poll_answers.user_id = User.current.id
      
        @poll_answers.save
      }
     
    end
    # El parametro remote es enviado desde la pagina del formulario, si tiene 
    # valor true no redirecciona a nada, si es valor false redirecciona a la 
    # pagina de inicio
    if params[:remote] == true
      respond_to do |format|
        format.html { render :nothing => true }
        format.js   { render :nothing => true }
      end
    else
      redirect_to home_url
    end
  end
  
  def send_poll_by_mail
    raise_delivery_errors = ActionMailer::Base.raise_delivery_errors
    # Force ActionMailer to raise delivery errors so we can catch it
    ActionMailer::Base.raise_delivery_errors = true
    begin
      @test = Mailer.poll_fill(params[:user_id], params[:project_id], params[:issue_id]).deliver
    rescue Exception => e
      puts ":::::::::::::::::::::::::ERROR SENDING MAIL TO #{params[:user_id]}"
      puts "#{e}"
    end
    ActionMailer::Base.raise_delivery_errors = raise_delivery_errors
  end
end
