# Port of Spinel benchmark/bm_so_lists.rb (from the Doug Bagley shootout).
# NUM and SIZE are parameters; returns the final result of test_lists.
# Deviation from original: the unreachable `p "not SIZE"` branch returns 0 without printing.
module SoListsKernel
  def self.test_lists(size)
    # create a list of integers (Li1) from 1 to SIZE
    li1 = (1..size).to_a
    # copy the list to li2 (not by individual items)
    li2 = li1.dup
    # remove each individual item from left side of li2 and
    # append to right side of li3 (preserving order)
    li3 = Array.new
    while (not li2.empty?)
      li3.push(li2.shift)
    end
    # li2 must now be empty
    # remove each individual item from right side of li3 and
    # append to right side of li2 (reversing list)
    while (not li3.empty?)
      li2.push(li3.pop)
    end
    # li3 must now be empty
    # reverse li1 in place
    li1.reverse!
    # check that first item is now SIZE
    if li1[0] != size then
      0
    else
      # compare li1 and li2 for equality
      if li1 != li2 then
        return(0)
      else
        # return the length of the list
        li1.length
      end
    end
  end

  def self.so_lists(num, size)
    result = 0
    i = 0
    while i < num
      i += 1
      result = test_lists(size)
    end
    result
  end
end
