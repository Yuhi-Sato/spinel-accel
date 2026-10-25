# Port of Spinel benchmark/bm_str_concat.rb (yjit-bench str_concat).
# Returns result.length, which is what the original prints.
module StrConcatKernel
  def self.concat_test(n, str_to_add)
    s = +""
    i = 0
    while i < n
      s << str_to_add
      i = i + 1
    end
    s
  end

  def self.run(n, str_to_add)
    concat_test(n, str_to_add).length
  end
end
