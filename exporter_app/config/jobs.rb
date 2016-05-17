{
  jobs: [
    WeekdayJob.new(:identifier => 'ead',
                   :description => 'Export EAD versions of resource records',
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

    WeekdayJob.new(:identifier => 'plaintext',
                   :description => 'Export plaintext versions of resource records',
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

                     # Our EAD -> Plaintext XSLT
                     :xslt_transforms => ['https://raw.githubusercontent.com/saa-ead-roundtable/ead-stylesheets/14d937a237e449874947dcf4b96a9d10ffc6c942/dsc-3-column-table/threecolumn_dsc.xsl'],
                   },

                   :before_hooks => [
                     ShellRunner.new("scripts/prepare_workspace.sh"),
                   ],

                   :after_hooks => [
                     ErbRenderer.new("templates/manifest.md.erb", "README.md"),
                     ShellRunner.new("scripts/commit_workspace.sh"),
                   ]),

    WeekdayJob.new(:identifier => 'git_repository',
                   :description => 'Combine repositories for the other jobs and push them up daily',
                   :days_of_week => ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'],
                   :start_time => '00:00',
                   :end_time => '23:59',
                   :minimum_seconds_between_runs => 5,

                   :task => RepositoryMergeTask,
                   :task_parameters => {
                     :jobs_to_merge => ['ead', 'plaintext'],

                     # You can use a URL with an embedded username or password like this
                     :git_remote => 'https://yourusername:yourpassword@github.com/yourusername/yourrepo.git',

                     # Or you can use an SSH URL with a Github deploy key
                     # configured.  See the `bin/generate_deploy_key.sh` script
                     # for instructions on how to do that.
                     # :git_remote => 'git@github.com:yourusername/yourrepo.git',
                   })
  ]
}
