class XMLException < StandardError
  def initialize(msg, cause)
    msg = (msg +
           "\n" +
           ("=" * 72) +
           "\n" +
           cause +
           "\n" +
           ("=" * 72) +
           "\n")

    super(msg)
    @cause = cause
  end

  def cause
    @cause
  end
end
