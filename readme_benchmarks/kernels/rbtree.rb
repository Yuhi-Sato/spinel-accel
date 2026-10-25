# Left-leaning red-black tree insert benchmark.
# Returns the lines the original prints, joined with "\n".
# Note: the result is built via string interpolation so Ruby returns a UTF-8
# string (Integer#to_s/join yield US-ASCII, which verify mode treats as a
# mismatch against the native UTF-8 result).
module RbtreeKernel
  class RBNode
    attr_accessor :key, :left, :right, :red
    def initialize(key)
      @key = key
      @left = nil
      @right = nil
      @red = 1
      @tag = "rb"
    end
  end

  def self.is_red(node)
    if node.nil?
      return 0
    end
    node.red
  end

  def self.rotate_left(h)
    x = h.right
    h.right = x.left
    x.left = h
    x.red = h.red
    h.red = 1
    x
  end

  def self.rotate_right(h)
    x = h.left
    h.left = x.right
    x.right = h
    x.red = h.red
    h.red = 1
    x
  end

  def self.flip_colors(h)
    h.red = 1
    h.left.red = 0
    h.right.red = 0
  end

  def self.insert_node(h, key)
    if h.nil?
      return RBNode.new(key)
    end
    if key < h.key
      h.left = insert_node(h.left, key)
    elsif key > h.key
      h.right = insert_node(h.right, key)
    end
    if is_red(h.right) == 1 && is_red(h.left) == 0
      h = rotate_left(h)
    end
    if is_red(h.left) == 1
      if h.left != nil && is_red(h.left.left) == 1
        h = rotate_right(h)
      end
    end
    if is_red(h.left) == 1 && is_red(h.right) == 1
      flip_colors(h)
    end
    h
  end

  def self.count_nodes(h)
    if h.nil?
      return 0
    end
    1 + count_nodes(h.left) + count_nodes(h.right)
  end

  def self.run(n, rebuilds)
    lines = []
    # Use typed initial assignment
    root = RBNode.new(0)
    root = nil
    i = 0
    while i < n
      key = (i * 7919 + 1) % 100000
      root = insert_node(root, key)
      i = i + 1
    end
    root.red = 0

    lines << count_nodes(root).to_s

    # Rebuild `rebuilds` times
    j = 0
    while j < rebuilds
      root = nil
      i = 0
      while i < n
        key = (i * 7919 + j) % 100000
        root = insert_node(root, key)
        i = i + 1
      end
      root.red = 0
      j = j + 1
    end
    lines << count_nodes(root).to_s
    lines << "done"
    "#{lines.join("\n")}"
  end
end
