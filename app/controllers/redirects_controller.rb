# The redirect engine (PRD_V1 §3): looks up a shortlink and sends the visitor
# on immediately. Click capture is enqueued, never inline, so a slow write
# never touches the redirect's latency.
class RedirectsController < ApplicationController
  allow_unauthenticated_access

  def show
    shortlink = Shortlink.active.find_by(host: request.host_with_port, slug: params[:slug])
    return render plain: "Not found", status: :not_found if shortlink.nil?

    # Sending visitors off-host is the whole point of a shortener, so the guard is on the
    # scheme rather than the host: anything explicitly schemed must be http(s), which blocks
    # a stored javascript:/data: target while still allowing a bare "wa.me/…" destination.
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
