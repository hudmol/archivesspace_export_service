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
                   :days_of_week => ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'],
                   :start_time => '00:00',
                   :end_time => '23:59',

                   :task => ExportEADTask,
                   :task_parameters => {
                     :workspace_directory => ExporterApp.base_dir('workspace/001'),
                     :export_options => {
                       :include_unpublished => false,
                       :include_daos => false,
                       :numbered_cs => false
                     },
                     :archivesspace_ead_schema => 'config/ead.xsd',
                     :xslt_transforms => ['config/transform.xslt'],
                   },

                   :before_hooks => [
                     ShellRunner.new("scripts/prepare_workspace.sh"),
                   ],

                   :after_hooks => [
                     ErbRenderer.new("templates/manifest.html.erb", "manifest.html"),
                     ShellRunner.new("scripts/commit_workspace.sh"),
                   ],

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
