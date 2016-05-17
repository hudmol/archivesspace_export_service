{
  jobs: [
    WeekdayJob.new(:identifier => '001',
                   :description => 'Every morning',
                   :days_of_week => ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'],
                   :start_time => '00:00',
                   :end_time => '23:59',
                   :minimum_seconds_between_runs => 5,

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

                     :validation_schema => ['config/ead.xsd'],
                     :xslt_transforms => ['config/transform.xslt'],
                   },

                   :before_hooks => [
                     ShellRunner.new("scripts/prepare_workspace.sh"),
                   ],

                   :after_hooks => [
                     ErbRenderer.new("templates/manifest.md.erb", "README.md"),
                     ShellRunner.new("scripts/commit_workspace.sh"),
                   ]),

    WeekdayJob.new(:identifier => '002',
                   :description => 'Every morning',
                   :days_of_week => ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'],
                   :start_time => '00:00',
                   :end_time => '23:59',
                   :minimum_seconds_between_runs => 5,

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

                     :validation_schema => ['config/ead.xsd'],
                     :xslt_transforms => ['config/transform.xslt'],
                   },

                   :before_hooks => [
                     ShellRunner.new("scripts/prepare_workspace.sh"),
                   ],

                   :after_hooks => [
                     ErbRenderer.new("templates/manifest.md.erb", "README.md"),
                     ShellRunner.new("scripts/commit_workspace.sh"),
                   ]),

    WeekdayJob.new(:identifier => '003',
                   :description => 'Combine repositories for the other jobs and push them up daily',
                   :days_of_week => ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'],
                   :start_time => '00:00',
                   :end_time => '23:59',
                   :minimum_seconds_between_runs => 5,

                   :task => RepositoryMergeTask,
                   :task_parameters => {
                     :jobs_to_merge => ['001', '002'],
                     :git_remote => 'https://yourusername:yourpassword@github.com/yourusername/yourrepo.git'
                   })
  ]
}
