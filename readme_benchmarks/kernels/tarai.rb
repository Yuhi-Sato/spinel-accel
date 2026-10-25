# Port of Spinel benchmark/bm_tarai.rb. Returns tarai(x, y, z) instead of printing it (and "done").
module TaraiKernel
  def self.tarai(x, y, z)
    if x <= y
      y
    else
      tarai(tarai(x - 1, y, z), tarai(y - 1, z, x), tarai(z - 1, x, y))
    end
  end
end
