# GCBench (from yjit-bench) - binary tree construction benchmark.
# Returns "done" (what the original prints).
module GcbenchKernel
  class Node
    attr_accessor :left, :right, :i, :j
    def initialize
      @left = nil
      @right = nil
      @i = 0
      @j = 0
      @tag = "n"
    end
  end

  def self.tree_size(depth)
    (1 << (depth + 1)) - 1
  end

  def self.num_iters(stretch_depth, depth)
    2 * tree_size(stretch_depth) / tree_size(depth)
  end

  def self.populate(depth, node)
    if depth > 0
      node.left = Node.new
      node.right = Node.new
      populate(depth - 1, node.left)
      populate(depth - 1, node.right)
    end
  end

  def self.make_tree(depth)
    if depth <= 0
      Node.new
    else
      n = Node.new
      n.left = make_tree(depth - 1)
      n.right = make_tree(depth - 1)
      n
    end
  end

  def self.time_construction(stretch_depth, depth)
    n = num_iters(stretch_depth, depth)
    i = 0
    while i < n
      node = Node.new
      populate(depth, node)
      i = i + 1
    end
    i = 0
    while i < n
      make_tree(depth)
      i = i + 1
    end
  end

  def self.run(stretch_depth, long_lived_depth, min_depth, max_depth)
    make_tree(stretch_depth)

    long_lived = Node.new
    populate(long_lived_depth, long_lived)

    depth = min_depth
    while depth <= max_depth
      time_construction(stretch_depth, depth)
      depth = depth + 2
    end

    "done"
  end
end
