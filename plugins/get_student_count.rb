require './canhelplib'

module CanhelpPlugin
  include Canhelp

  def self.get_student_count(
    canvas_url=prompt(:canvas_url),
    account_id=prompt(:account_id),
    student_role_id = prompt(:student_role_id)
  )
    token = get_token
    subaccount_ids = get_json_paginated(
      token, "#{canvas_url}/api/v1/accounts/#{account_id}/sub_accounts", "recursive=true"
    ).map{|s| s['id']}
    subaccount_ids << account_id

    puts "\t"
    puts "Grabbing enrollments from courses in the following accounts:"
    subaccount_ids.each do |subaccount|
      puts "- #{subaccount}"
    end

    all_student_enrollments = []

    subaccount_ids.each do |subaccount_id|
      courses = get_json_paginated(
      token,
      "#{canvas_url}/api/v1/accounts/#{subaccount_id}/courses",
      "include[]=total_students&include[]=teachers&state[]=available&state[]=completed"
      )

      courses.each do |course|
        if course['workflow_state'] != 'unpublished'
          course_ids = course['id']
          enrollments = get_json_paginated(
            token,
            "#{canvas_url}/api/v1/courses/#{course_ids}/enrollments",
            "state[]=active&state[]=completed&type[]=StudentEnrollment"
          )

          course_name = course['name']
          course_state = course['workflow_state']
          total_students = course['total_students']
          teacher_display_name = course['teachers']

          teacher_display_name.each do |teacher|
            teacher_name = teacher['display_name']
            puts
            puts "Teacher's Name: #{teacher_name}"
          end

          puts
          puts "- Course Name: #{course_name}"
          puts
          puts "- State: #{course_state}"
          puts
          puts "- Total number of students: #{total_students}"
          puts

          enrollments.each do |enrollment|
            if enrollment['role_id'].to_s == "#{student_role_id}"
              all_student_enrollments << enrollment

              student_name = enrollment['user']['name']
              student_sis = enrollment['user']['sis_user_id']
              student_workflow_state = enrollment['enrollment_state']

              puts "- Student's Name: #{student_name} - #{student_sis} - #{student_workflow_state}"

            end
          end
        end
      end
    end

    student_ids = all_student_enrollments.map { |enrollment|
      enrollment['user_id']
    }.uniq

    all_student_info = student_ids.map do |id|
      student_enrollment = all_student_enrollments.find { |enrollment|
        enrollment['user_id'] == id
      }
      next if student_enrollment.nil?

      "#{student_enrollment['user']['name']} - #{student_enrollment['user_id']} | #{student_enrollment['sis_user_id']} | #{student_enrollment['created_at']} | #{student_enrollment['updated_at']}"
    end.sort_by(&:downcase)

    total_student_count = student_ids.count

    puts
    puts "Total number of active and completed StudentEnrollments: #{total_student_count}"
    puts
    puts "All Students' Names: "
    all_student_info.each do |name|
      puts "- #{name}"
    end
  end
end
