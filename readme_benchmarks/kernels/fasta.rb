# Port of Spinel benchmark/bm_fasta.rb (The Computer Language Benchmarks Game - Fasta).
# Returns the text the original prints (every line terminated by "\n") instead of printing it.
# Deviation from original: the global RNG state `$last` is replaced by a one-element
# integer array threaded through the helpers (kernels must not use globals); the
# IUB/HOMO tables become module constants.
module FastaKernel
  IM = 139968
  IA = 3877
  IC = 29573

  ALU = "GGCCGGGCGCGGTGGCTCACGCCTGTAATCCCAGCACTTTGGGAGGCCGAGGCGGGCGGATCACCTGAGGTCAGGAGTTCGAGACCAGCCTGGCCAACATGGTGAAACCCCGTCTCTACTAAAAATACAAAAATTAGCCGGGCGTGGTGGCGCGCGCCTGTAATCCCAGCTACTCGGGAGGCTGAGGCAGGAGAATCGCTTGAACCCGGGAGGCGGAGGTTGCAGTGAGCCGAGATCGCGCCACTGCACTCCAGCCTGGGCGACAGAGCGAGACTCCGTCTCAAAAAAA"

  IUB_CHARS = ["a", "c", "g", "t", "B", "D", "H", "K", "M", "N", "R", "S", "V", "W", "Y"]
  IUB_PROBS = [0.27, 0.12, 0.12, 0.27, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02]

  HOMO_CHARS = ["a", "c", "g", "t"]
  HOMO_PROBS = [0.3029549426680, 0.1979883004921, 0.1975473066391, 0.3015094502008]

  def self.gen_random(last, max)
    last[0] = (last[0] * IA + IC) % IM
    max * last[0] / IM
  end

  def self.make_repeat_fasta(out, id, desc, src, n)
    out.push(">" + id + " " + desc)
    k = 0
    i = 0
    while i < n
      len = 60
      if n - i < 60
        len = n - i
      end
      line = ""
      j = 0
      while j < len
        line = line + src[k % src.length]
        k = k + 1
        j = j + 1
      end
      out.push(line)
      i = i + len
    end
  end

  def self.make_random_fasta(out, last, id, desc, table_chars, table_probs, n)
    out.push(">" + id + " " + desc)
    # Build cumulative probabilities
    cp = Array.new(table_probs.length, 0.0)
    sum = 0.0
    k = 0
    while k < table_probs.length
      sum = sum + table_probs[k]
      cp[k] = sum
      k = k + 1
    end
    i = 0
    while i < n
      len = 60
      if n - i < 60
        len = n - i
      end
      line = ""
      j = 0
      while j < len
        r = gen_random(last, 1.0)
        # Linear search
        c = 0
        while c < cp.length - 1
          if r < cp[c]
            break
          end
          c = c + 1
        end
        line = line + table_chars[c]
        j = j + 1
      end
      out.push(line)
      i = i + len
    end
  end

  def self.fasta(n)
    last = [42]
    out = []
    make_repeat_fasta(out, "ONE", "Homo sapiens alu", ALU, n * 2)
    make_random_fasta(out, last, "TWO", "IUB ambiguity codes", IUB_CHARS, IUB_PROBS, n * 3)
    make_random_fasta(out, last, "THREE", "Homo sapiens frequency", HOMO_CHARS, HOMO_PROBS, n * 5)
    out.join("\n") + "\n"
  end
end
