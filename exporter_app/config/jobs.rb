# Use cases:
#
#  * Run every morning at 2am for 4 hours
#
#  * Run every Friday night at 2am
#
#  * Run this job once, right now

{
  jobs: [
    WeekdayJob.new(:job_identifier => '001',
                   :job_name => 'Every morning',
                   :days_of_week => ['Mon', 'Tue', 'Wed', 'Fri'],
                   :start_time => '10:00',
                   :end_time => '6:00',

                   :task => ExportEADTask,
                   :task_parameters => {
                     :workspace_directory => ExporterApp.base_dir('workspace/001'),
                     :export_options => {
                       :include_unpublished => false,
                       :include_daos => false,
                       :numbered_cs => false
                     }
                     # :pipeline => [
                     #   Pipeline::ValidateXML.new("schema.xsd"),
                     #   Pipeline::XSLTransformXML.new("my.xsl"),
                     # ]
                   }

                   # :task => SleepTask,
                   # :task_parameters => {}
                  ),

    # WeekdayJob.new(:job_identifier => '002',
    #                :job_name => 'Friday night',
    #                :days_of_week => ['Fri'],
    #                :start_time => '2:00',
    #                :end_time => '6:00'),
    # 
    # IntervalJob.new(:job_identifier => '003',
    #                 :job_name => 'Important Resource',
    #                 :interval_minutes => 60),
    # 
    # OneOffJob.new(:job_identifier => '004',
    #               :job_name => 'Do it!'),


  ]
}
