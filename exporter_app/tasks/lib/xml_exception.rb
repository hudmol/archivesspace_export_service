class XMLException < StandardError
  def initialize(msg, cause = nil)
    if cause
      msg = (msg +
             "\n" +
             ("=" * 72) +
             "\n")

      msg += cause.class.to_s + ': ' + cause.message + "\n"

      msg += ("=" * 72) + "\n"
    end

    super(msg)
    @cause = cause
  end

  def cause
    @cause
  end
end
