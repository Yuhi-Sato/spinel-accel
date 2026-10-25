# Port of Spinel benchmark/bm_ackermann.rb. Returns ack(m, n) instead of printing it (and "done").
module AckermannKernel
  def self.ack(m, n)
    if m == 0
      n + 1
    elsif n == 0
      ack(m - 1, 1)
    else
      ack(m - 1, ack(m, n - 1))
    end
  end
end
