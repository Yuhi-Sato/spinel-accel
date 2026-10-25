# The Computer Language Benchmarks Game
# Binary Trees - class-based nodes.
# Returns the lines the original prints, joined with "\n".
# Note: the result is built via string interpolation so Ruby returns a UTF-8
# string (Integer#to_s/join yield US-ASCII, which verify mode treats as a
# mismatch against the native UTF-8 result).
module BinaryTreesKernel
  class Node
    attr_accessor :left, :right
    def initialize(left, right)
      @left = left
      @right = right
    end
  end

  def self.make_tree(depth)
    if depth == 0
      return Node.new(nil, nil)
    end
    d = depth - 1
    Node.new(make_tree(d), make_tree(d))
  end

  def self.check_tree(node)
    if node.left == nil
      return 1
    end
    1 + check_tree(node.left) + check_tree(node.right)
  end

  def self.run(max_depth)
    lines = []
    min_depth = 4
    if min_depth + 2 > max_depth
      max_depth = min_depth + 2
    end

    stretch_depth = max_depth + 1
    stretch_tree = make_tree(stretch_depth)
    lines << check_tree(stretch_tree).to_s

    long_lived_tree = make_tree(max_depth)

    depth = min_depth
    while depth <= max_depth
      iterations = 2 ** (max_depth - depth + min_depth)
      check = 0
      i = 1
      while i <= iterations
        t = make_tree(depth)
        check = check + check_tree(t)
        i = i + 1
      end
      lines << check.to_s
      depth = depth + 2
    end

    lines << check_tree(long_lived_tree).to_s
    "#{lines.join("\n")}"
  end
end
