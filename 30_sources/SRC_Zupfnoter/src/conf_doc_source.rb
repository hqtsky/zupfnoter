$:.unshift File.dirname(__FILE__)
require 'redcarpet'
require 'json'

require 'neatjson'
require 'i18n'
require 'init_conf'
require 'confstack'

HELP_DE_INPUT     = "localization/help_de-de.md"
HELP_DE_OUTPUT_MD = "../../UD_Zupfnoter-Handbuch/090_UD_Zupfnoter-Konfiguration.md"

Encoding.default_internal = Encoding::UTF_8
Encoding.default_external = Encoding::UTF_8

# init_conf uses symbols. This does not matter in Opal
# but ruby it is a difference. So we have to stringify the keys.
class Hash
  # Returns a deep copy of hash.
  #
  #   hash = { a: { b: 'b' } }
  #   dup  = hash.deep_dup
  #   dup[:a][:c] = 'c'
  #
  #   hash[:a][:c] # => nil
  #   dup[:a][:c]  # => "c"
  def stringify_keys
    hash = {}
    each_pair do |key, value|
      if value.is_a? Hash
        hash[key.to_s] = value.stringify_keys
      else
        hash[key.to_s] = value
      end
    end
    hash
  end
end

class ConfDocProvider

  attr_reader :entries_html, :entries_md

  def initialize
    @renderer     = Redcarpet::Markdown.new(Redcarpet::Render::HTML, autolink: true, tables: true)
    @entries_md   = {}
    @entries_html = {}
  end

  def insert (key, markdown)
    @entries_md[key.gsub("\\", "")]   = markdown
    ## need to strip the escape characters from key. This suports "$resources". the escape key is introduced
    # by wortsammler (pandoc)
    # note that we have to replace '-s-' by '#' due to weaknes of redcarped mardown processor
    @entries_html[key.gsub("\\", "")] = @renderer.render(markdown).gsub("-s-", "#")
  end

  def to_json
    JSON.neat_generate(@entries_html)
  end

end


class Document
  def self.ready?

  end
end


def get_example(conf, key)
  neatjson_options = {wrap:          60, aligned: true, after_comma: 1, after_colon_1: 1, after_colon_n: 1, before_colon_n: 1, sorted: true,
                      explicit_sort: [[:produce, :annotations, :restposition, :default, :repeatstart, :repeatend, :extract,
                                       :title, :voices, :flowlines, :subflowlines, :synchlines, :jumplines, :repeatsigns, :layoutlines, :barnumbers, :countnotes, :legend, :notes, :lyrics, :nonflowrest, :tuplet, :layout,
                                       :annotation, :partname, :variantend, :countnote, :stringnames, # sort within notebound
                                       :limit_a3, :LINE_THIN, :LINE_MEDIUM, :LINE_THICK, :ELLIPSE_SIZE, :REST_SIZE, # sort within layout
                                       "0", "1", "2", "3", "4", "5", "6", :verses, # extracts
                                       :cp1, :cp2, :shape, :pos, :hpos, :vpos, :spos, :text, :style, :marks # tuplets annotations
                                      ].map{|i| i.to_s},
                                      []],
  }
  k                = key.split(".").last

  %Q{
"#{k}": #{JSON.neat_generate(conf[key], neatjson_options)}
  }.split("\n").map {|l| "        #{l}"}.join("\n")
end

a=ConfDocProvider.new

File.open(HELP_DE_INPUT).read.scan(/## ([^\n]*)([^#]*)/).sort_by {|i| i[0]}.each do |match|
  a.insert(match[0], match[1])
end

#-- generate helptexts

File.open("../public/locale/conf-help_de-de.json", "w") do |f|
  f.puts a.to_json
end


#-- generate configuration doc

$conf_helptext = a.entries_html

ignore_patterns  = [/^neatjson.*/, /abc_parser.*/, /^extract\.[235].*/, /^defaults.*/, /^templates.*/, /^annotations.*/, /^extract\.[1234]/,
                    /^layout.*/, /^extract\.0$/,  /^presets$/, /^presets\..*$/
]
produce_patterns = [/annotations\.vl/, /^templates\.tuplets/, /^extract$/, /^templates/, /^annotations/,
                    /^presets\.notes/, /^presets\.barnumbers_countnotes\.countnotes_with_lyrics\..*/]
cleanup_patterns = [/presets\.notes.*\.value/, /presets\.notes.*\.T01_number_extract_value\.*/]
extra_keys       = ['extract.0.notebound.minc', 'extract.0.notebound.minc.x.minc_f', "extract.0.notebound.tuplet"]

locale = JSON.parse(File.read('../public/locale/de-de.json'))

$conf        = Confstack.new(false)
$conf.push(InitConf.init_conf.stringify_keys)

ignore_keys  = $conf.keys.select {|k| ignore_patterns.select {|ik| k.match(ik)}.count > 0}
produce_keys = $conf.keys.select {|k| produce_patterns.select {|ik| k.match(ik)}.count > 0}
cleanup_keys = $conf.keys.select {|k| cleanup_patterns.select {|ik| k.match(ik)}.count > 0}
show_keys    = ($conf.keys - ignore_keys + produce_keys + extra_keys - cleanup_keys).uniq.sort_by {|k| k.gsub('templates', 'extract.0')}

mdhelp = []
show_keys.sort.each do |key|
  show_key = key #.gsub(/^templates\.([a-z]+)(\.)/){|m| "extract.0.#{$1}.0."}

  candidate_keys = I18n.get_candidate_keys(key)
  candidates     = candidate_keys.map {|c| a.entries_md[c.join('.')]}

  helptext = candidates.compact.first || %Q{TODO: Helptext für #{key} einfügen }
  keyparts = key.split(".")

  #\\index{#{keyparts.last.gsub("_", "-")}}\\index{#{keyparts.join(",").gsub("_", "-")}}

  # note that we have to replace '-s-' by '#' due to weaknes of redcarped mardown processor
  result   = %Q{

## `#{show_key}` - #{locale['phrases'][key.split(".").last]} {##{show_key}}

  #{helptext.gsub('-s-', '#')}

  #{get_example($conf, key) rescue "... kein Beispiel verfügbar ..."}
  }
  mdhelp.push result
end


File.open(HELP_DE_OUTPUT_MD, "w") do |f|
  f.puts %Q{
<!--
do not edit this file. it is generated by rake build from #{HELP_DE_INPUT}

maintain the keys to be shown here in #{__FILE__}
-->

# Konfiguration der Ausgabe {#konfiguration}

Dieses Kapitel beschreibt die Konfiguration der Erstellung der Unterlegnotenblätter. Das Kapitel ist als Referenz aufgebaut.
Die einzelnen Konfigurationsparameter werden in alphabetischer Reihenfolge aufgeführt. Bei den einzelnen Parametern
wird der Text der Online-Hilfe, sowie die Voreinstellungen des Systems dargestellt.

>**Hinweis**: Auch wenn in den Bildschirmmasken die Namen der Konfigurationsparameter übersetzt sind, so basiert
>diese Referenz den englischen Namen.

>**Hinweis**: Manche Konfigurationsparameter können mehrfach auftreten (z.B. `extract`). In diesem Kapitel wird
>dann immer die Instanz mit der Nr. 0 (z.B. `extract.0`) beschrieben.
          }
  f.puts mdhelp
end


# ---- generate missing locales


require './controller.rb'
require './confstack.rb'
require 'neatjson.rb'


a = InitConf.init_conf
b = Confstack.new(false)
b.push(JSON.parse(a.to_json))

knownkeys = JSON.parse(File.read("../public/locale/de-de.json"))
abc2svgkeys = JSON.parse(File.read("localization/abc2svg_de-de.json"))
w2uikeys = JSON.parse(File.read("../vendor/w2ui/dist/de-de.json"))
usedkeys  = []
keys      = []
Dir['user-interface.js', "config-form.rb"].each do |file|
  File.read(file).scan(/(caption|text|tooltip):\s*["']([^'"]*)["']/) do |clazz, key|
    key = key.gsub("\\n", "\n")
    usedkeys.push(key)
    keys.push(key) unless knownkeys['phrases'].has_key? key
  end
  File.read(file).scan(/(w2utils\.lang\()["']([^'"]*)["']\)/) do |clazz, key|
    key = key.gsub("\\n", "\n")
    usedkeys.push(key)
    keys.push(key) unless knownkeys['phrases'].has_key? key
  end
end

Dir['*.rb'].each do |file|
  File.read(file).scan(/(I18n\.t)\(['"]([^'"]+)['"]/) do |clazz, key|
    key = key.gsub("\\n", "\n")
    usedkeys.push(key)
    keys.push(key) unless knownkeys['phrases'].has_key? key
  end
end

b.keys.each do |key|
  key.split(".").each do |key|
    usedkeys.push(key)
    keys.push(key) unless knownkeys['phrases'].has_key? key
  end
end

File.open("x.locales.template", "w") do |f|
  f.puts keys.sort.to_a.map {|v| %Q{"#{v}": "**--#{v}"}}.uniq.sort_by {|i| i.upcase}.join(",\n")
end

File.open("x.locales.unused.txt", "w") do |f|
  f.puts knownkeys['phrases'].keys - usedkeys - abc2svgkeys['phrases'].keys - w2uikeys['phrases'].keys
end
