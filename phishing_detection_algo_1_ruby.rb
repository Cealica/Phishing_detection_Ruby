require 'gtk3'
require 'sqlite3'
require 'nokogiri'
require 'open-uri'

# Create a new SQLite3 database
db = SQLite3::Database.new 'blacklist.db'

# Create a table to store URLs
db.execute <<-SQL
  CREATE TABLE IF NOT EXISTS urls (
    id INTEGER PRIMARY KEY,
    url TEXT NOT NULL
  );
SQL

# Check if the given URL is in the blacklisted database
def check_blacklist(db, url)
  db.execute("SELECT * FROM urls WHERE url = ?", [url]).any?
end

# Check if the given URL is a possible phishing site
def check_phishing(db, url)
  begin
    # Parse the HTML of the URL
    doc = Nokogiri::HTML(open(url))

    # Check if the URL looks like a well-known social platform
    if doc.at_css("title").text =~ /^(Facebook|Twitter|LinkedIn|Instagram)/
      # Add the URL to the blacklist
      db.execute("INSERT INTO urls (url) VALUES (?)", [url])

      return true
    end

    # Check if the URL contains forms for personal information
    doc.css("form").each do |form|
      if form.at_css("input[type=text]") && form.at_css("input[type=password]")
        # Add the URL to the blacklist
        db.execute("INSERT INTO urls (url) VALUES (?)", [url])

        return true
      end
    end

    # If none of the checks above returned true, return false
    false
  rescue
    # If there was an error opening the URL, return false
    false
  end
end

# Block the given URL if it is blacklisted or a possible phishing site
def block_url(db, url)
  if check_blacklist(db, url)
    puts "The URL is blacklisted and has been blocked."
  elsif check_phishing(db, url)
    puts "The URL is a possible phishing site and has been blocked."
  else
    puts "The URL is not blacklisted or a phishing site. Proceed with caution."
  end
end


# Create a new GTK window
win = Gtk::Window.new
win.set_title("URL Checker")
win.set_border_width(10)
win.set_default_size(400, 100)

# Use the built-in Adwaita theme for a more modern look and feel
settings = Gtk::Settings.default
settings.gtk_theme_name = "Adwaita"

# Create a new entry field for the URL
url_entry = Gtk::Entry.new

# Set the default text for the entry field
url_entry.set_placeholder_text("Enter a URL")

# Create a new label for displaying the results
results_label = Gtk::Label.new

# Create a new vertical box container
vbox = Gtk::Box.new(:vertical, 10)

# Create a new function to display an emoji depending on the result of the checks
def show_emoji(url, result)
  if result == :good
    # Return a green checkmark emoji if the link is good
    return "\u2705"
  elsif result == :bad
    # Return a red letter X emoji if the link is bad
    return "\u274C"
  elsif result == :blocked
    # Return a brick wall emoji if the link is blocked
    return "\u1F6A9"
  end
end




# Create a new button for blocking the URL
block_button = Gtk::Button.new(:label => "Block URL")
block_button.signal_connect("clicked") {
  # Get the URL from the entry field
  url = url_entry.text

  # Add the URL to the blacklist
  db.execute("INSERT INTO urls (url) VALUES (?)", [url])

  # Update the results label with the result of the check
  results_label.set_text("The URL has been manually blocked.")
}

# Add the entry field, label, and buttons to the container
vbox.pack_start(url_entry, :expand => false, :fill => true, :padding => 0)
vbox.pack_start(results_label, :expand => false, :fill => true, :padding => 0)
vbox.pack_start(block_button, :expand => false, :fill => true, :padding => 0)

# Create a new button for checking the URL
check_button = Gtk::Button.new(:label => "Check URL")
check_button.signal_connect("clicked") {
  # Get the URL from the entry field
  url = url_entry.text

  # Block the URL if necessary
  block_url(db, url)

  # Update the results label with the result of the check
  if check_blacklist(db, url)
    results_label.set_text("The URL is blacklisted and has been blocked.")
  elsif check_phishing(db, url)
    results_label.set_text("The URL is a possible phishing site and has been blocked.")
  else
    results_label.set_text("The URL is not blacklisted or a phishing site. Proceed with caution.")
  end
}

# Add the check button to the container
vbox.pack_start(check_button, :expand => false, :fill => true, :padding => 0)

# Add the container to the GTK window
win.add(vbox)

# Show the GTK window and start the main loop
win.show_all
Gtk.main

