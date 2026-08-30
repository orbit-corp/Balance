class Llm::ExplicitApproval
  APPROVAL_PATTERN = /\A\s*(?:
    y(?:es|eah|ep|up)?|
    ok(?:ay)?|sure|alright|go\s+ahead|do\s+it|proceed|approved?|confirmed?|
    (?:(?:yes|yeah|yep|yup|ok(?:ay)?|sure|alright)[,\s]+)?
    (?:please\s+)?(?:record|post|approve|confirm)
    (?:\s+(?:it|this|the\s+(?:entry|proposal)))?
  )\s*[.!]?\s*\z/ix

  def self.call(content)
    content.to_s.match?(APPROVAL_PATTERN)
  end
end
