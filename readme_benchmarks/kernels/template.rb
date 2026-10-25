# Port of Spinel benchmark/bm_template.rb.
# run(iterations) renders the three test templates, then renders the first
# template `iterations` times, and returns the printed lines joined with "\n".
module TemplateKernel
  def self.render(template, vars)
    result = ""
    i = 0
    while i < template.length
      if i + 1 < template.length && template[i] == "{" && template[i + 1] == "{"
        # Find closing }}
        j = i + 2
        while j + 1 < template.length
          if template[j] == "}" && template[j + 1] == "}"
            break
          end
          j = j + 1
        end
        key = template[i + 2, j - i - 2]
        if vars.has_key?(key)
          result = result + vars[key]
        else
          result = result + "{{" + key + "}}"
        end
        i = j + 2
      else
        result = result + template[i]
        i = i + 1
      end
    end
    result
  end

  def self.run(iterations)
    tmpl = "Hello {{name}}! You are {{age}} years old. Welcome to {{city}}."
    vars = {"name" => "Matz", "age" => "58", "city" => "Matsue"}
    out1 = render(tmpl, vars)

    tmpl2 = "{{greeting}} {{name}}, {{message}}"
    vars2 = {"greeting" => "Hi", "name" => "World", "message" => "how are you?"}
    out2 = render(tmpl2, vars2)

    out3 = render("{{known}} and {{unknown}}", {"known" => "yes"})

    i = 0
    while i < iterations
      render(tmpl, vars)
      i = i + 1
    end
    out1 + "\n" + out2 + "\n" + out3 + "\n" + "done"
  end
end
