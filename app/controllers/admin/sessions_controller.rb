module Admin
  class SessionsController < ApplicationController
    allow_unauthenticated_access only: %i[new create]

    rate_limit to: 5, within: 1.minute, only: :create,
               with: -> { redirect_to admin_login_path, alert: "Too many attempts. Try again in a minute." }

    def new
      redirect_to root_path if admin_authenticated?
    end

    def create
      return render :new, status: :service_unavailable unless AdminPassword.configured?

      if AdminPassword.matches?(params[:password])
        return_to = session[:admin_return_to]
        reset_session
        session[:admin_authenticated_at] = Time.current.to_i
        redirect_to safe_return_to(return_to), notice: "Signed in."
      else
        flash.now[:alert] = "Incorrect password."
        render :new, status: :unprocessable_entity
      end
    end

    def destroy
      reset_session
      redirect_to dashboard_path, notice: "Signed out."
    end

    private

    def safe_return_to(path)
      path.to_s.start_with?("/") && !path.to_s.start_with?("//") ? path : root_path
    end
  end
end
