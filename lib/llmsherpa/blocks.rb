module Llmsherpa
  # A block is a node in the layout tree. It can be a paragraph, a list item, a table, or a section header.
  # This is the base class for all blocks such as Paragraph, ListItem, Table, Section.
  class Block
    attr_accessor :tag, :level, :page_idx, :block_idx, :top, :left, :bbox, :sentences, :children, :parent, :block_json

    def initialize(block_json=nil)
      @tag = block_json['tag'] if block_json && block_json.key?('tag')
      @level = (block_json['level'] if block_json && block_json.key?('level')) || 0
      @page_idx = block_json['page_idx'] if block_json && block_json.key?('page_idx')
      @block_idx = block_json['block_idx'] if block_json && block_json.key?('block_idx')
      @top = block_json['top'] if block_json && block_json.key?('top')
      @left = block_json['left'] if block_json && block_json.key?('left')
      @bbox = block_json['bbox'] if block_json && block_json.key?('bbox')
      @sentences = block_json['sentences'] if block_json && block_json.key?('sentences')
      @children = []
      @parent = nil
      @block_json = block_json
    end

    # Adds a child to the block. Sets the parent of the child to self.
    def add_child(node)
      @children.push(node)
      node.parent = self
    end

    # Converts the block to html. This is a virtual method and should be implemented by the derived classes.
    def to_html(include_children=false, recurse=false)
    end

    # Converts the block to text. This is a virtual method and should be implemented by the derived classes.
    def to_text(include_children=false, recurse=false)
    end

    # Returns the parent chain of the block consisting of all the parents of the block until the root.
    def parent_chain
      chain = []
      parent = self.parent
      while parent
        chain.push(parent)
        parent = parent.parent
      end
      chain.reverse
    end

    # Returns the text of the parent chain of the block. This is useful for adding section information to the text.
    def parent_text
      parent_chain = self.parent_chain
      header_texts = []
      para_texts = []
      parent_chain.each do |p|
        if p.tag == "header"
          header_texts.push(p.to_text)
        elsif ['list_item', 'para'].include?(p.tag)
          para_texts.push(p.to_text)
        end
      end
      text = header_texts.join(" > ")
      text += "\n" + para_texts.join("\n") unless para_texts.empty?
      text
    end

    # Returns the text of the block with section information. This provides context to the text.
    def to_context_text(include_section_info=true)
      text = ""
      text += self.parent_text + "\n" if include_section_info
      if ['list_item', 'para', 'table'].include?(@tag)
        text += self.to_text(true, true)
      else
        text += self.to_text
      end
      text
    end

    # Iterates over all the children of the node and calls the node_visitor function on each child.
    def iter_children(node, level, &node_visitor)
      node.children.each do |child|
        node_visitor.call(child)
        self.iter_children(child, level + 1, &node_visitor) unless ['list_item', 'para', 'table'].include?(child.tag)
      end
    end

    # Returns all the paragraphs in the block. This is useful for getting all the paragraphs in a section.
    def paragraphs
      paragraphs = []
      self.iter_children(self, 0) do |node|
        paragraphs.push(node) if node.tag == 'para'
      end
      paragraphs
    end

    # Returns all the chunks in the block. Chunking automatically splits the document into paragraphs, lists, and tables without any prior knowledge of the document structure.
    def chunks
      chunks = []
      self.iter_children(self, 0) do |node|
        chunks.push(node) if ['para', 'list_item', 'table'].include?(node.tag)
      end
      chunks
    end

    # Returns all the tables in
    # Returns all the tables in the block. This is useful for getting all the tables in a section.
    def tables
      tables = []
      self.iter_children(self, 0) do |node|
        tables.push(node) if node.tag == 'table'
      end
      tables
    end

    # Returns all the sections in the block. This is useful for getting all the sections in a document.
    def sections
      sections = []
      self.iter_children(self, 0) do |node|
        sections.push(node) if node.tag == 'header'
      end
      sections
    end
  end

  # A paragraph is a block of text. It can have children such as lists. A paragraph has tag 'para'.
  class Paragraph < Block
    def initialize(para_json)
      super(para_json)
    end

    def to_text(include_children=false, recurse=false)
      para_text = @sentences.join("\n")
      if include_children
        @children.each do |child|
          para_text += "\n" + child.to_text(include_children: recurse, recurse: recurse)
        end
      end
      para_text
    end

    def to_html(include_children=false, recurse=false)
      html_str = "<p>"
      html_str += @sentences.join("\n")
      if include_children && !@children.empty?
        html_str += "<ul>"
        @children.each do |child|
          html_str += child.to_html(include_children: recurse, recurse: recurse)
        end
        html_str += "</ul>"
      end
      html_str += "</p>"
      html_str
    end
  end

  # A section is a block of text. It can have children such as paragraphs, lists, and tables. A section has tag 'header'.
  class Section < Block
    attr_accessor :title

    def initialize(section_json)
      super(section_json)
      @title = @sentences.join("\n")
    end

    def to_text(include_children=false, recurse=false)
      text = @title
      if include_children
        @children.each do |child|
          text += "\n" + child.to_text(include_children: recurse, recurse: recurse)
        end
      end
      text
    end

    def to_html(include_children=false, recurse=false)
      html_str = "<h#{@level + 1}>#{@title}</h#{@level + 1}>"
      if include_children
        @children.each do |child|
          html_str += child.to_html(include_children: recurse, recurse: recurse)
        end
      end
      html_str
    end
  end

  # A list item is a block of text. It can have child list items. A list item has tag 'list_item'.
  class ListItem < Block
    def initialize(list_json)
      super(list_json)
    end

    def to_text(include_children=false, recurse=false)
      text = @sentences.join("\n")
      if include_children
        @children.each do |child|
          text += "\n" + child.to_text(include_children: recurse, recurse: recurse)
        end
      end
      text
    end

    def to_html(include_children=false, recurse=false)
      html_str = "<li>"
      html_str += @sentences.join("\n")
      if include_children && !@children.empty?
        html_str += "<ul>"
        @children.each do |child|
          html_str += child.to_html(include_children: recurse, recurse: recurse)
        end
        html_str += "</ul>"
      end
      html_str += "</li>"
      html_str
    end
  end

  # A table cell is a block of text. It can have child paragraphs. A table cell has tag 'table_cell'.
  # A table cell is contained within table rows.
  class TableCell < Block
    attr_accessor :col_span, :cell_value, :cell_node

    def initialize(cell_json)
      super(cell_json)
      @col_span = cell_json['col_span'] if cell_json.key?('col_span')
      @cell_value = cell_json['cell_value']
      @cell_node = if @cell_value.is_a?(String)
                    nil
                  else
                    Paragraph.new(@cell_value)
                  end
    end

    def to_text
      cell_text = @cell_value
      cell_text = @cell_node.to_text if @cell_node
      cell_text
    end

    def to_html
      cell_html = @cell_value
      cell_html = @cell_node.to_html if @cell_node
      if @col_span == 1
        "<td colSpan='#{@col_span}'>#{cell_html}</td>"
      else
        "<td>#{cell_html}</td>"
      end
    end
  end

  # A table row is a block of text
  # Base Block class assumed to be defined elsewhere

  class TableRow < Block
    # Initializes a TableRow with child table cells
    def initialize(row_json)
      @cells = []
      if row_json['type'] == 'full_row'
        cell = TableCell.new(row_json)
        @cells << cell
      else
        row_json['cells'].each do |cell_json|
          cell = TableCell.new(cell_json)
          @cells << cell
        end
      end
    end

    # Returns text of a row with text from all the cells in the row delimited by '|'
    def to_text(include_children=false, recurse=false)
      cell_text = @cells.map(&:to_text).join(" | ")
      cell_text
    end

    # Returns html for a <tr> with html from all the cells in the row as <td>
    def to_html(include_children=false, recurse=false)
      html_str = "<tr>"
      @cells.each { |cell| html_str += cell.to_html }
      html_str += "</tr>"
      html_str
    end
  end

  class TableHeader < Block
    # Initializes a TableHeader with child table cells
    def initialize(row_json)
      super(row_json)
      @cells = []
      row_json['cells'].each do |cell_json|
        cell = TableCell.new(cell_json)
        @cells << cell
      end
    end

    # Returns text of a header row in markdown format
    def to_text(include_children=false, recurse=false)
      cell_text = @cells.map(&:to_text).join(" | ")
      cell_text += "\n" + @cells.map { "---" }.join(" | ")
      cell_text
    end

    # Returns html for a <th> with html from all the cells in the row as <td>
    def to_html(include_children=false, recurse=false)
      html_str = "<th>"
      @cells.each { |cell| html_str += cell.to_html }
      html_str += "</th>"
      html_str
    end
  end

  # The Table and Document classes would be similarly translated, focusing on Ruby's syntax for inheritance, method definitions, and iteration.
  # The `initialize` method in Ruby is used instead of `__init__` in Python, and instance variables are prefixed with `@`.
  # Method definitions in Ruby do not require the `def` keyword for each argument, and blocks of code are enclosed in `do...end` instead of indentation.

  # This conversion assumes the presence of similarly functional TableCell, Paragraph, ListItem, and Section classes or modules in Ruby.
  class Table < Block
    # Initializes a Table with child table rows and headers
    def initialize(table_json, parent)
      super(table_json)
      @rows = []
      @headers = []
      @name = table_json["name"]
      if table_json.include?('table_rows')
        table_json['table_rows'].each do |row_json|
          if row_json['type'] == 'table_header'
            row = TableHeader.new(row_json)
            @headers << row
          else
            row = TableRow.new(row_json)
            @rows << row
          end
        end
      end
    end

    # Returns text of a table with text from all the rows in the table delimited by '\n'
    def to_text(include_children=false, recurse=false)
      text = @headers.map { |header| header.to_text }.join("\n") + "\n" +
            @rows.map { |row| row.to_text }.join("\n")
      text
    end

    # Returns html for a <table> with html from all the rows in the table as <tr>
    def to_html(include_children=false, recurse=false)
      html_str = "<table>"
      @headers.each { |header| html_str += header.to_html }
      @rows.each { |row| html_str += row.to_html }
      html_str += "</table>"
      html_str
    end
  end

  class Document
    # Initializes a Document with a layout tree from the json
    def initialize(blocks_json)
      @reader = LayoutReader.new
      @root_node = @reader.read(blocks_json)
      @json = blocks_json
    end

    # Returns all the chunks in the document
    def chunks
      @root_node.chunks
    end

    # Returns all the tables in the document
    def tables
      @root_node.tables
    end

    # Returns all the sections in the document
    def sections
      @root_node.sections
    end

    # Returns text of a document by iterating through all the sections '\n'
    def to_text
      text = sections.map { |section| section.to_text(include_children=true, recurse=true) }.join("\n")
      text
    end

    # Returns html for the document by iterating through all the sections
    def to_html
      html_str = "<html>"
      sections.each { |section| html_str += section.to_html(include_children=true, recurse=true) }
      html_str += "</html>"
      html_str
    end
  end

  class LayoutReader
    # Reads the layout tree from the JSON returned by the parser API.
    
    def debug(pdf_root)
      iter_children = lambda do |node, level|
        node.children.each do |child|
          puts "#{"-" * level} #{child.tag} (#{child.children.length}) #{child.to_text}"
          iter_children.call(child, level + 1)
        end
      end
      iter_children.call(pdf_root, 0)
    end

    def read(blocks_json)
      root = Block.new
      parent_stack = [root]
      prev_node = root
      parent = root
      list_stack = []

      blocks_json.each do |block|
        if block['tag'] != 'list_item' && !list_stack.empty?
          list_stack = []
        end

        node = case block['tag']
        when 'para'
          Paragraph.new(block)
        when 'table'
          Table.new(block, prev_node)
        when 'list_item'
          ListItem.new(block)
        when 'header'
          Section.new(block)
        else
          raise "Unsupported block type: #{block['tag']}"
        end

        if block['tag'] == 'para'
          parent.add_child(node)
        elsif block['tag'] == 'table'
          parent.add_child(node)
        elsif block['tag'] == 'list_item'
          if prev_node.tag == 'para' && prev_node.level == node.level
            list_stack << prev_node
          elsif prev_node.tag == 'list_item'
            if node.level > prev_node.level
              list_stack << prev_node
            elsif node.level < prev_node.level
              while !list_stack.empty? && list_stack.last.level > node.level
                list_stack.pop
              end
            end
          end
          if list_stack.any?
            list_stack.last.add_child(node)
          else
            parent.add_child(node)
          end
        elsif block['tag'] == 'header'
          if node.level > parent.level
            parent_stack << node
            parent.add_child(node)
          else
            while parent_stack.length > 1 && parent_stack.last.level >= node.level
              parent_stack.pop
            end
            parent_stack.last.add_child(node)
            parent_stack << node
          end
          parent = node
        end

        prev_node = node
      end

      root
    end
  end
end