# Port of Spinel benchmark/bm_csv_process.rb.
# run(n, iterations) generates n CSV lines, processes them once plus
# `iterations` more times, and returns every printed line joined with "\n"
# (including the final "done"). process_lines returns its output lines
# instead of printing them.
# Deviation from original: the returned string is built as "" + join so it is
# UTF-8 in Ruby too (the first line comes from Integer#to_s, which CRuby tags
# US-ASCII while Spinel returns UTF-8).
module CsvProcessKernel
  def self.generate_lines(n)
    depts = ["eng", "sales", "hr", "ops"]
    names = ["alice", "bob", "carol", "dave", "eve"]
    lines = ["name,dept,salary,age"]
    i = 0
    while i < n
      name = names[i % 5]
      dept = depts[i % 4]
      salary = 30000 + (i * 1337) % 70000
      age = 22 + i % 40
      lines.push(name + "," + dept + "," + salary.to_s + "," + age.to_s)
      i = i + 1
    end
    lines
  end

  def self.process_lines(lines, out)
    total_salary = 0
    high_earners = 0
    dept_counts = {}
    i = 1
    while i < lines.length
      fields = lines[i].split(",")
      if fields.length >= 4
        dept = fields[1]
        salary = fields[2].to_i
        total_salary = total_salary + salary
        if salary >= 80000
          high_earners = high_earners + 1
        end
        if dept_counts.has_key?(dept)
          dept_counts[dept] = dept_counts[dept] + 1
        else
          dept_counts[dept] = 1
        end
      end
      i = i + 1
    end
    out.push((lines.length - 1).to_s)
    out.push(total_salary.to_s)
    out.push(high_earners.to_s)
    dept_counts.each { |k, v|
      out.push(k + ": " + v.to_s)
    }
    out
  end

  def self.run(n, iterations)
    out = []
    lines = generate_lines(n)
    process_lines(lines, out)

    i = 0
    while i < iterations
      process_lines(lines, out)
      i = i + 1
    end
    out.push("done")
    "" + out.join("\n")
  end
end
