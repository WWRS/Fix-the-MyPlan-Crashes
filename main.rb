require 'digest/sha1'
require 'sequel'
require 'sinatra'

# For printing source code
source_code = File.read('main.rb').gsub('&', '&amp;').gsub('>', '&gt;').gsub('<', '&lt;')

# Make DBs
DB = Sequel.sqlite

DB.create_table :classes do
    Integer :sln, primary_key: true
    Integer :start_time
    Integer :end_time
    Integer :size
end
classes_db = DB[:classes]

DB.create_table :buffer_schedule do
    primary_key :id
    String :hash, null: false
    Integer :student_id, null: false
    String :classes, null: false
end
buffer_schedule = DB[:buffer_schedule]

DB.create_table :final_schedule do
    Integer :student_id, primary_key: true
    String :classes, null: false
end
final_schedule = DB[:final_schedule]

# Settings
student_count = 10000
class_count = 5000
classes_per_student = 10

# Sinatra stuff
set :bind, '0.0.0.0'
get '/' do
    # Remove old data
    classes_db.truncate
    buffer_schedule.truncate
    final_schedule.truncate
    
    # Set up classes
    class_count.times do |i|
        time = rand(1440)
        size = rand(90) + 10
        classes_db.insert(sln: i, start_time: time, end_time: time + 50, size: size)
    end

    # Fill the buffer
    student_count.times do |i|
        id = i
        classes = classes_per_student.times.map{rand(class_count)}.join(' ')
        hash = Digest::SHA1.hexdigest("#{id}w19SALT")
        buffer_schedule.insert(hash: hash, student_id: id, classes: classes)
    end
    
    # Start timing
    t1 = Time.now
    
    # Cache seats available
    seats_available = classes_db.all.map{|h| [h[:sln], h[:size]] }.to_h
    
    # Start dumping people in
    buffer_list = buffer_schedule.order(:hash)
    fail_count = 0
    buffer_list.each do |h|
        want_classes = h[:classes].split.map(&:to_i)
        got_classes = []
        failed_any = false
        
        want_classes.each do |sln|
            if seats_available[sln] > 0
                seats_available[sln] -= 1
                got_classes << sln
            else
                failed_any = true
            end
        end
        
        final_schedule.insert(student_id: h[:student_id], classes: got_classes.join(' '))
        
        # Normally here, you'd add them to a email notification list
        if failed_any
            fail_count += 1
        end
    end
    
    # Stop timing
    t2 = Time.now
    
    # Return result
    result_html = "Wrote #{student_count} students into #{class_count} classes at #{classes_per_student} classes per student. <br> Time taken: #{t2 - t1} seconds. <br> Failures: #{fail_count}. <br><br><br>"
    source_html = "Source: <br> <pre>#{source_code}</pre>"
    return result_html + source_html
end
