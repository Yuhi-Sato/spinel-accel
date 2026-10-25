# Port of Spinel benchmark/bm_linked_list.rb.
# Deviation from original: the result text is built with string interpolation (not
# Integer#to_s + concatenation) so Ruby returns UTF-8 like the native build instead of US-ASCII.
# The list size (100000) and rebuild count (10) are parameters; returns the lines the
# original prints joined with "\n" (including the final "done"). LNode is nested in the module.
module LinkedListKernel
  class LNode
    attr_accessor :val, :nxt
    def initialize(val)
      @val = val
      @nxt = nil
      @tag = "ln"
    end
  end

  def self.list_push(head, val)
    node = LNode.new(val)
    node.nxt = head
    node
  end

  def self.list_length(head)
    n = 0
    cur = head
    while cur != nil
      n = n + 1
      cur = cur.nxt
    end
    n
  end

  def self.list_reverse(head)
    prev = nil
    cur = head
    while cur != nil
      nxt = cur.nxt
      cur.nxt = prev
      prev = cur
      cur = nxt
    end
    prev
  end

  def self.list_sum(head)
    s = 0
    cur = head
    while cur != nil
      s = s + cur.val
      cur = cur.nxt
    end
    s
  end

  def self.linked_list(size, reps)
    out = []
    # Build list of `size` elements
    head = nil
    i = 0
    while i < size
      head = list_push(head, i)
      i = i + 1
    end
    out.push("#{list_length(head)}")
    out.push("#{list_sum(head)}")

    # Reverse and sum
    head = list_reverse(head)
    out.push("#{list_sum(head)}")

    # Rebuild + reverse `reps` times
    j = 0
    while j < reps
      head = nil
      i = 0
      while i < size
        head = list_push(head, i)
        i = i + 1
      end
      head = list_reverse(head)
      j = j + 1
    end
    out.push("#{list_length(head)}")
    out.push("done")
    out.join("\n")
  end
end
