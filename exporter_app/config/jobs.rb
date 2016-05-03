# Use cases:
#
#  * Run every morning at 2am for 4 hours
#
#  * Run every Friday night at 2am
#
#  * Run this job once, right now

{
  jobs: [
    WeekdayJob.new(:identifier => '001',
                   :description => 'Every morning',
                   :days_of_week => ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'],
                   :start_time => '00:00',
                   :end_time => '23:59',

                   :task => ExportEADTask,
                   :task_parameters => {
                     :search_options => {
#                       :repo_id => 2,
#                       :identifier => 'AAA.02.G',
#                       :start_id => 'AAA.01',
#                       :end_id => 'ZZZ.99',
                     },
                     :export_options => {
                       :include_unpublished => false,
                       :include_daos => false,
                       :numbered_cs => false
                     },

                     # :archivesspace_ead_schema_validations => ['config/ead.xsd'],
                     :xslt_transforms => ['config/transform.xslt'],
                   },

                   :before_hooks => [
                     ShellRunner.new("scripts/prepare_workspace.sh"),
                   ],

                   :after_hooks => [
                     ErbRenderer.new("templates/manifest.html.erb", "manifest.html"),
                     ShellRunner.new("scripts/commit_workspace.sh"),
                   ]),

    WeekdayJob.new(:identifier => '002',
                   :description => 'Every morning',
                   :days_of_week => ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'],
                   :start_time => '00:00',
                   :end_time => '23:59',

                   :task => ExportEADTask,
                   :task_parameters => {
                     :search_options => {
#                       :repo_id => 2,
#                       :identifier => 'AAA.02.G',
#                       :start_id => 'AAA.01',
#                       :end_id => 'ZZZ.99',
                     },
                     :export_options => {
                       :include_unpublished => false,
                       :include_daos => false,
                       :numbered_cs => false
                     },

                     # :archivesspace_ead_schema_validations => ['config/ead.xsd'],
                     :xslt_transforms => ['config/transform.xslt'],
                   },

                   :before_hooks => [
                     ShellRunner.new("scripts/prepare_workspace.sh"),
                   ],

                   :after_hooks => [
                     ShellRunner.new("scripts/commit_workspace.sh"),
                   ]),

    WeekdayJob.new(:identifier => '003',
                   :description => 'Combine repositories for the other jobs and push them up daily',
                   :days_of_week => ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'],
                   :start_time => '00:00',
                   :end_time => '23:59',

                   :task => RepositoryMergeTask,
                   :task_parameters => {
                     :jobs_to_merge => ['001', '002'],
                     :git_remote => 'somewhere'
                   })


    # IntervalJob.new(:identifier => '003',
    #                 :description => 'Important Resource',
    #                 :interval_minutes => 60),
    # 
    # OneOffJob.new(:identifier => '004',
    #               :description => 'Do it!'),


  ]
}
