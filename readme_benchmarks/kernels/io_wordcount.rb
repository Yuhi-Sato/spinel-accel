# Port of Spinel benchmark/bm_io_wordcount.rb.
# Deviation from original: kernels cannot do file I/O, so instead of writing
# /tmp/spinel_io_wf.txt with File#puts and reading it back with
# File.open + each_line, the same content is built in memory as a String
# (each line ending in "\n", as File#puts would write) and processed with
# String#each_line. Returns the printed lines joined with "\n" (incl. "done").
module IoWordcountKernel
  def self.run(n, iterations)
    # Write test data: word frequency "file"
    words = ["the", "quick", "brown", "fox", "jumps", "over", "lazy", "dog"]
    data = +""
    i = 0
    while i < n
      w = words[i % 8]
      data << w + " " + (i % 100).to_s + "\n"
      i = i + 1
    end

    # Process: count word frequencies
    counts = {}
    data.each_line do |line|
      parts = line.strip.split(" ")
      if parts.length >= 1
        word = parts[0]
        if counts.has_key?(word)
          counts[word] = counts[word] + 1
        else
          counts[word] = 1
        end
      end
    end

    out = []
    counts.each do |k, v|
      out.push(k + ": " + v.to_s)
    end

    i = 0
    while i < iterations
      c = {}
      data.each_line do |line|
        parts = line.strip.split(" ")
        if parts.length >= 1
          w = parts[0]
          if c.has_key?(w)
            c[w] = c[w] + 1
          else
            c[w] = 1
          end
        end
      end
      i = i + 1
    end

    out.push("done")
    out.join("\n")
  end
end
