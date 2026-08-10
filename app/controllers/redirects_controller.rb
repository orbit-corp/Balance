class RedirectsController < ApplicationController
  allow_unauthenticated_access

  def show
    shortlink = Shortlink.active.find_by(host: request.host_with_port, slug: params[:slug])
    return render plain: "Not found", status: :not_found if shortlink.nil?

    destination = shortlink.redirect_url
    scheme = destination.to_s[%r{\A([a-z][a-z0-9+.\-]*):}i, 1]
    return render plain: "Not found", status: :not_found if scheme && !%w[http https].include?(scheme.downcase)

    ClickRecorderJob.perform_later(
      shortlink_id: shortlink.id,
      ref_code: shortlink.ref_code,
      ip_address: request.remote_ip,
      user_agent: request.user_agent,
      referrer: request.referrer,
      occurred_at: Time.current
    )

    redirect_to destination, allow_other_host: true, status: :found
  end
end
