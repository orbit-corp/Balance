class ApplicationController < ActionController::Base
  include Authentication

  allow_browser versions: :modern

  stale_when_importmap_changes

  helper_method :current_workspace

  private
    def current_workspace
      Current.user.workspace
    end

    def redirect_out_of_frame(url, notice:)
      respond_to do |format|
        format.turbo_stream do
          flash[:notice] = notice
          render turbo_stream: turbo_stream.action(:redirect, url)
        end

        format.html { redirect_to url, notice: notice }
      end
    end

    def available_chat_models
      RubyLLM.models.chat_models.all
             .sort_by { |model| [ model.provider.to_s, model.name.to_s ] }
    end
end
