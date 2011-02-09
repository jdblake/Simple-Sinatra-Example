# Sinatra app to store grades for students (1 grade per student)

# I require rubygems in my sinatra code so I don't need the '-rubygems' switch when I start the app
require 'rubygems'

# This is a neat trick. I am turning the list of libraries into an array of strings, then iterating over
# the array to require each gem individually. This one line substitutes for all of the following:
#
# require 'sinatra'
# require 'dm-core'
# require 'dm-migrations'
# require 'haml'
%w{sinatra dm-core dm-migrations haml}.each {|gem| require gem}
# Note that _all_ the other requires can be added to this list. I have kept them broken out because
# they have annotations associated with them.

# Library for validating data in the records
require 'dm-validations'

# The following library allows you to log things from your code. I use it to dump messages
# to keep an eye on things. The logs are named after the level you are running your app at. Choices
# are development, test, production. The default is development, but when you deploy it is set to
# production by Rack
require 'sinatra/logger'

# I like to log to a file and not STDOUT... I find it annoying to have those messages
# constantly scrolling by on the terminal. BTW: The log level of :debug is the lowest level,
# meaning everything gets logged including DB queries. There are other levels that would
# (in my opinion) be more appropriate for productions systems. Check the DataMapper::Logger
# docs at http://datamapper.rubyforge.org/dm-core
#
# NOTE 1: more docs at http://datamapper.rubyforge.org/dm-more/
# NOTE 2: I log to files in a <log> subdirectory because this is where sinatra/logger expects logs
DataMapper::Logger.new('log/dm.log', :debug)

# Save the data in the db directory. The db starts empty and all additions are saved
DataMapper.setup(:default, "sqlite://#{Dir.pwd}/db/grades.sqlite3")

# Student class. Note that I have added an id to serve as a key, although you can use something from
# the list of fields as a key
#
# If you want, you can put all your models in a sub-directory, and require them in code by using something
# like the following:
#
# Dir.glob("#{Dir.pwd}/models/*.rb") { |m| require "#{m.chomp}" }
#
# The Student class code could be in a file called student.rb, and each model would become available to
# your app. The example assumes the sub-directory is called 'models'

class Student
  include DataMapper::Resource

  # Class properties
  property :id, Serial
  property :name, String
  property :grade, Integer

  # Simple validation to ensure that the grade is an integer. Note the custom error message!
  # 
  # You can submit any numeric grade and this validation will succeed. The data in the URI that
  # represents a student grad is a string that is cast to an integer. Real numbers are just truncated.
  # If you try to submit a string for a grade, however, this will fail!
  validates_numericality_of :grade, :integer_only => true,
      :message => "You must store an integer for a grade!"
end

# Initialize (finalize) db
DataMapper.finalize

# Create the db/tables if they don't exist
DataMapper::auto_upgrade!

# Set up the logger. To do so, set the root of the app, and set the log level:
#   Log levels (low->high): debug, info, warn, error, fatal
set :root, "#{Dir.pwd}"
set :logger_level, :debug

# Root route ;)
#
# This route shows a simple page that displays the entries in the database in a list on the page. The
# list is updated every second through jQuery/AJAX
#
# I am rendering the pages using haml. You can include simple haml templates inline at the bottom of this
# file (see the documentation), but I have chosen to break them out in a separate views folder for clarity
#
# Navigate to this route to see the AJAX in action. For best effect, influence the db either by
# using irb to inject records, or by opening a second browser window to set values in the db. Either way
# the AJAX will cause this page to change as the db changes (it is currently set to update every second)
get '/?' do
  haml :index
end

# Set a grade for a student (the '/?' at the end of the URI means that this handler will match requests
# with an optional trailing slash
get "/set/:name/:grade/?" do |name,grade|
  # Default return
  ret = "Student record saved"

  newRecord = false

  # Get the student record for the given name
  curStudent = Student.first(:name => name)

  # If the record doesn't exist, make a new one
  unless curStudent then
    newRecord = true

    curStudent = Student.new(:name => name)
  end

  # Set the grade in the record
  curStudent.grade = grade

  # Save the record
  if curStudent.save then
    # Log that a record had to be generated
    logger.debug("SET: New student record generated. Name: <#{name}>") if newRecord

    # Log the transaction
    logger.debug("SET: Grade set to <#{curStudent.grade}> for <#{name}>")
  else
    # Log the last error fro the array of errors
    curStudent.errors.each { |e| logger.error("SET: #{e[-1]}") }

    ret = "Student record not saved. Check the log!"
  end

  # Simple output message
  ret
end

# Get a grade for a student. Return -1 if the student doesn't exist
get "/get/:name/?" do |name|
  # Default return value
  ret = -1

  # Get the student record for the given name, or make a new one if there is no record
  curStudent = Student.first(:name => name)

  # Set the student grade if the name is in the db
  if curStudent then
    # Get the grade
    ret = curStudent.grade

    # Log the transaction
    logger.debug("GET: Returning grade of <#{ret}> for <#{name}>")
  else
    # Log that the student record dosen't exist
    logger.debug("GET: Student <#{name}> not in db")
  end

  # Return the resulting value
  "#{ret}"
end

# Dump all the records in the db. This handler is executed when you send a basic get request to the URL
# and a list of tuples from the database is returned
get '/dumpString/?' do
  # Return variable
  ret = ""
  
  # Get the records
  students = Student.all

  # Log the transaction
  logger.debug("Dumping #{students.length} records")

  # Concatenate the student grades from the db
  students.each { |s| ret += "(#{s.name},#{s.grade})" } if students

  ret
end

# Respond to a post request with an array of the records in the database. Render the haml w/o layout to
# turn the array to an HTML list.
post '/dumpArray' do
  # Get the students in the db
  @students = Student.all

  # Render the list
  haml :studentArray, :layout => false
end
