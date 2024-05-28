# coding: utf-8
# autoxref-treeprocessor.rb: Automatic cross-reference generator.
#
# Copyright (c) 2016 Takahiro Yoshimura <altakey@gmail.com>
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
#
# 1. Redistributions of source code must retain the above copyright
# notice, this list of conditions and the following disclaimer.
#
# 2. Redistributions in binary form must reproduce the above copyright
# notice, this list of conditions and the following disclaimer in the
# documentation and/or other materials provided with the distribution.
#
# 3. Neither the name of the copyright holder nor the names of its
# contributors may be used to endorse or promote products derived from
# this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
# FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
# COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
# INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
# BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
# ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
require 'asciidoctor/extensions'

include Asciidoctor

Extensions.register do
  treeprocessor AutoXrefTreeprocessor
end

# A treeprocessor that allows refering sections and titled
# images/listings/tables with their reference number (e.g. Figure
# <chapter number>.1, <chapter number>.2, ... for images).
#
# Works by assigning reference number-based captions (RNBCs) for
# targets, and updates reference table in the document with them.
#
# Run using:
#
# asciidoctor -r ./lib/autoxref-treeprocessor.rb lib/autoxref-treeprocessor/sample.adoc
class AutoXrefTreeprocessor < Extensions::Treeprocessor
  def process document
    # The initial value of the chapter counter.
    initial_chapter = attr_of(document, 'autoxref-chapter') { 0 }

    # The section level we should treat as chapters.
    chapter_section_level = (document.attr 'autoxref-chaptersectlevel', 1).to_i

    # Captions should we use.
    captions = {
      :chapter => (document.attr 'autoxref-chapcaption', "Capítulo %d"),
      :section => (document.attr 'autoxref-sectcaption', "Seção %d.%d"),
      :image => (document.attr   'autoxref-imagecaption', "Figura %d.%d"),
      :listing => (document.attr 'autoxref-listingcaption', "Programa %d.%d"),
      :table => (document.attr   'autoxref-tablecaption', "Tabela %d.%d"),
	    :example => (document.attr 'autoxref-examplecaption', "Exemplo %d.%d")
    }

    # Reference number counter.  Reference numbers are reset by chapters.
    counter = {
      :chapter => initial_chapter,
      :section => 1,
      :image => 1,
      :listing => 1,
      :table => 1,
	  :example => 1
    }
	
    seen = false	
		
    # Scan for chapters.
    document.find_by(context: :section).each do |chapter|
      next unless not seen or chapter.level == chapter_section_level
      seen = true

      # XXX crude care for chapterless documents
      if chapter.level != chapter_section_level then
        chapter = document
      end

      # Assign chapter number and reset our reference numbers.
      chap = attr_of(chapter, 'autoxref-chapter') { get_and_tally_counter_of(:chapter, counter) }
      counter.update(
        {
          :section => 1,
          :image => 1,
          :listing => 1,
          :table => 1,
		      :example => 1
        }
      )	  
	   

      # Scan for sections, titled images/listings/tables in the chapter.
      [:section, :image, :listing, :table, :example].each do |type|
        chapter.find_by(context: type).each do |el|
          # Generate RNBCs for eligible targets and update reference table in the document.  For non-sections, we also overwrite their captions with RNBCs.
          if type != :section then
            if el.title? then
              replaced = captions[type] % [chap, get_and_tally_counter_of(type, counter)]
              replaced_caption = replaced + ' '
              el.attributes['caption'] = replaced_caption
              el.caption = replaced_caption
              document.references[:ids][el.attributes['id']] = replaced
            end
          elsif el.level == chapter_section_level + 1 then
            replaced = captions[type] % [chap, get_and_tally_counter_of(type, counter)]
            document.references[:ids][el.attributes['id']] = replaced
          end
        end
      end
    
		# Scan for exercises
		chapter.find_by(context: :section).each do |section|
			# Generate RNBCs for exercises and update reference table in the document.
			if section.title == "Exercícios" and section.level == 2 then
				exercise = 1
				section.find_by(context: :olist).each do |list|
					# Only do lists containing exercises, not sub-parts of exercises.
					unless list.parent.class == Asciidoctor::ListItem
						unless exercise == 1
							list.attributes["start"] = exercise.to_s
						end
						list.find_by(context: :list_item).each do |item|
							# Only do exercises, not sub-parts of exercises.						
							unless item.parent.parent.class == Asciidoctor::ListItem
								# Hack needed because item.text returns text with substitutions already applied.
								text = item.instance_variable_get :@text
								number = "%d.%d" % [chap, exercise]
								update_exercise_anchor_text(text, number, document)												
								exercise = exercise + 1						
							end
						end						
					end
				end
			end
		end		
	end

	# Update xrefs inside paragraphs.
	document.find_by(context: :paragraph).each do |paragraph|
		paragraph.lines.each do |line|		
			update_reference_text(line, document)
		end
	end
	
	# Update xrefs inside list_items.
	document.find_by(context: :list_item).each do |item|
		# Hack needed because item.text returns text with substitutions already applied.
		# Also, the unary plus is used to get a non-frozen string.
		text = +(item.instance_variable_get :@text)
		update_reference_text(text, document)
		item.instance_variable_set(:@text, text)
	end
	
	# Update xrefs inside titles (which are what appear as captions in text).
	[:section, :image, :listing, :table, :example].each do |type|
		document.find_by(context: type).each do |item|			
			if item.title? then
				# Same tricks as above.
				text = +(item.instance_variable_get :@title)
				update_reference_text(text, document)
				item.instance_variable_set(:@title, text)
			end
		end
	end
	
    nil
  end
  
   # Generate RNBCs for exercises and update reference table in the document.
   def update_exercise_anchor_text text, number, document
    pattern = /\[\[.+?\]\]/
    text.scan(pattern).each do |match|		
		unless match.include? ","						
			id = match[2, match.length - 4]				
			document.references[:ids][id] = "Exercício " + number
		end		
	end
  end

  # Given text, find any xrefs inside.
  # If the xref doesn't already have a custom name, set its name to the updated version.
  def update_reference_text text, document
    pattern = /<<.+?>>/
	# Find all the xrefs needing replacement in the text.	
	text.scan(pattern).each do |match|
		unless match.include? ","							
			id = match[2, match.length - 4]			
			# Add the custom name to the xref.
			unless document.references[:ids][id].nil?						
				text.sub! match, "<<" + id + "," + document.references[:ids][id] + ">>"
			end
		end
	end
  end

  # Gets and increments the value for the given type in the given
  # counter.
  def get_and_tally_counter_of type, counter
    t = counter[type]
    counter[type] = counter[type] + 1
    t
  end

  # Retrieves the associated value for the given key. Lazily retrieve
  # default value if no attr is set on the given key.
  def attr_of target, key, &default
    begin
      (target.attr key, :none).to_i
    rescue NoMethodError
      if not default.nil? then default.call else 0 end
    end
  end
end
