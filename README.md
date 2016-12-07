# ArchivesSpace Export Service

The ArchivesSpace Export Service provides a framework for scheduled
EAD export and publication.  It consists of an ArchivesSpace plug-in
and an application that uses the ArchivesSpace API but which is
otherwise independent of ArchivesSpace and can be deployed anywhere so
long as it has access to the ArchivesSpace backend.

The ArchivesSpace Export Service was developed by Hudson Molonglo for
Yale University.

## Installation

This git repository contains both the ArchivesSpace plug-in and the
Export Service Application.  Download a release from:

  https://github.com/hudmol/archivesspace_export_service/releases

### Plug-in

To install the plug-in, unzip the release into:

    /path/to/archivesspace/plugins

Like this:

    $ cd /path/to/archivesspace/plugins
    $ unzip archivesspace_export_service-vX.X.zip

Then enable the plugin by editing the file in `config/config.rb`:

    AppConfig[:plugins] = ['some_plugin', 'archivesspace_export_service']

(Make sure you uncomment this line (i.e., remove the leading '#' if present))

Then restart ArchivesSpace.

### Exporter Application

To install the Exporter Application unzip the release to wherever you
want to deploy it.  This could be where the plug-in is deployed, in
which case the unzipped release under plugins can be used.

The Exporter Application is entirely contained within the
`exporter_app` directory.

The only external dependency is java. Make sure you have installed the
correct version of java:

     java -version

It should be version 1.6 or newer.

Run the application like this:

    $ cd /path/to/archivesspace_export_service/exporter_app
    $ bin/startup.sh

And shut it down like this:

    $ cd /path/to/archivesspace_export_service/exporter_app
    $ bin/shutdown.sh

See below for configuration options.


## Application Configuration

The configuration for the Exporter Application is set in:

    /path/to/archivesspace_export_service/exporter_app/config/config.rb

Edit this file to set the url, username and password to access the ArchivesSpace API, like this:

    {
      aspace_username: 'a_user',
      aspace_password: 'secret_password',
      aspace_backend_url: 'http://localhost:8089/'
    }

Note that the ArchivesSpace user (`a_user`, here) will need
`view_repository` permission on any ArchivesSpace repository from
which resources will be exported.

Also note that the url is to the ArchivesSpace *backend*, not the
frontend web UI. If the Exporter Application is deployed on a
different machine from ArchivesSpace you may need to configure your
firewall to open the backend port.


## How it works

The plug-in creates a new endpoint on the ArchivesSpace backend that
provides lists of resources that have changed since a specified
time. It provides a list of `adds` or resources that should be
exported (or re-exported) for publication, and a list of `removes`
that have been deleted, or unpublished or suppressed, which should be
removed from the export pipeline.  Note, however, that removing a
record does not delete it from git's history: once a record has been
published to GitHub, it remains in the repository's history.

The Exporter Application runs as a daemon and uses a configuration
file (`config/jobs.rb` - discussed below) to determine when it should
start or stop export jobs.

Each export job remembers when it last ran, and whether it has any
unfinished items from its previous run.  It uses this information to
hit the new ArchivesSpace endpoint for the lists of `adds` and
`removes` for this run.

For each resource in the `adds` list it exports it as EAD and then
places it in a pipeline for processing.  The pipeline for each job is
configured in `config/jobs.rb`. It might include steps such as EAD
validation, XSLT transformation, and ultimately a publication
step. The current release contains a `Publish to Github` publisher. In
order to publish to a different kind of web service, it will be
necessary to develop a new publisher.

For each resource in the `removes` list it simply removes the exported
file (if it has been exported previously) and unpublishes it.

## Job Configuration

Jobs are configured in the `jobs.rb` file at:

    /path/to/archivesspace_export_service/exporter_app/config/jobs.rb

See the `jobs.rb` file that ships with the release for job
configuration examples.

The `jobs.rb` configuration file is Ruby code. At the top level it is
a Hash with one key `jobs`. The value of `jobs` is an array of
`WeekdayJob` objects. Each of these WeekdayJobs represents a scheduled
task (such as an export or a merge).

### Identity and Description

The following configuration options identify and describe the job:

  * `:identifier` -  A unique key for this job.

     Example: `:identifier => 'repo_1_ead'`

  * `:description` - A description of the job.

    Example: `:description => 'Export EAD for all of Repository 1'`

### Scheduling

The following configuration options specify the scheduling for the
job. A job is scheduled to run within a time window on particular days
of the week. If the job completes within its window, it will run
again, after a configurable delay. This will be repeated until the
window ends. Any unfinished exports will be resumed when the job is
next scheduled to run.

Available options are:

  * `:days_of_week` - The days of the week that the job should run
    on. Use three character string abbreviations in an array.

    Example: `:days_of_week => ['Mon', 'Tue', 'Wed', 'Thu']`

  * `:start_time` - The local time in hours and minutes (24 hour clock) that the job will
    be scheduled to run on the days specified above.

    Example: `:start_time => '23:05' # 11:05PM`

  * `:end_time` - The local time in hours and minutes (24 hour clock) that the job will
    be scheduled to stop running if it hasn't already completed. This
    allows jobs to be constrained to run within specified time windows -
    to avoid impacting system performance during business hours, for
    instance.

    If a job ends by hitting its `:end_time` (rather than by completing
    its work), any unfinished exports will be resumed when the job is next
    scheduled to run.

    Example: `:end_time => '08:30' # 8:30AM`

  * `:minimum_seconds_between_runs` - If a job finishes early within
    its run window, you might not want it to immediately start up
    again.  By setting `:minimum_seconds_between_runs`, you can
    control how long a job must wait before it can be rescheduled.
    For example, setting this to `86400` would force jobs to wait at
    least 24 hours before running again.

    Example: `:minimum_seconds_between_runs => 3600 # an hour`


## Tasks

Each job has a task. There are currently two task types -
`ExportEADTask` and `RepositoryMergeTask`. Their configuration options
are described below.

### ExportEADTask

The ExportEADTask exports records from the ArchivesSpace API in EAD
format, runs them through a configurable set of validations and
transformations, and writes the resulting records to a git repository.
Each batch of exported records is committed to the git repository with
a timestamp indicating when it was added.

Within the `jobs.rb` file, this task can be configured with a number
of `:task_parameters`.  These are as follows:

  * `:commit_every_n_records` - Forces the job to create intermediary
    git commits as it runs, rather than a single commit when the
    export finishes.  This saves on lost work if the job is
    interrupted mid-run for some reason.

  * `:search_options` - Provides scoping to control which records are
    candidates for export.  The available search options are:

      * :repo_id - The integer ID of the repository of interest (the
        default is to export from all repositories)

      * :identifier - The 4-part identifier of a single collection to
        be exported (the default is all collections)

      * :start_id, :end_id - Partial identifiers that form a range of
        resource IDs to export.  For example, a start of `AAA.01` and
        end of `ZZZ.99` would match records AAA.01, AAA.02, ...,
        XYZ.50, ..., ZZZ.01, ... ZZZ.98, ZZZ.99.

  * `:export_options` - Provides additional options to be passed to
    the ArchivesSpace export process.  Current available options are:

      * `:include_unpublished` - Whether unpublished components should
        be exported along with the resource (default: false)

      * `:include_daos` - Whether to include Digital Objects in dao
        tags (default: false)

      * `:numbered_cs` - Use numbered c tags in ead (default: false)

The sample `jobs.rb` file shows a fully configured ExportEADTask which
makes use of `:after_hooks` (described below) to additionally produce
PDF versions of finding aids and a table of contents.  Note that the
PDF task will make use of any fonts placed within `config/fonts`.

### RepositoryMergeTask

The `RepositoryMergeTask` allows the output of many other tasks to be
merged into one git repository.

Within the `jobs.rb` file, this task can be configured with a number
of `:task_parameters`.  These are as follows:

  * `:jobs_to_merge` - A list of job identifiers, the outputs of which
    should be merged.

  * `:job_descriptions` - A hash keyed on the included job
    identifiers. The values are descriptions of the jobs that, in the
    default configuration, will be written to the top-level README for
    the merged repository.

  * `:include_additional_files_from` - A directory, the contents of
    which will be added to the root of the git repository. Any `.erb`
    files included will be processed.

  * `:git_remote` - The URL of the remote git repository. See below.


## Validations and Transforms

The EAD export task performs several validation and transform steps,
described in this section.

### Schematron Validations

You can validate the EAD exported by the system using
[Schematron](http://schematron.com/) validations.  To do this, place
your Schematron `.sch` file into the `exporter_app/config` directory,
and then reference it in your ExportEADTask as follows:

     # See the sample jobs.rb file for a complete example
     :schematron_checks => ['config/my-schematron-file.sch'],

If an exported record fails its Schematron validation, the validation
error will be logged and the record skipped.

Note that you can provide multiple Schematron files if you want to
carry out more than one check.  Just add them to the list like this:

     :schematron_checks => ['config/my-schematron-file.sch', 'config/another-schematron-file.sch'],


### XSD Validations

In addition to Schematron files, you can also use regular XSD files to
carry out validations.  The process is identical as for Schematron but
for the property name you use.  Provide your XSD files to the
ExportEADTask like this:

     :validation_schema => ['config/ead.xsd', 'config/another.xsd'],


### XSLT Transforms

By providing one or more XSLT transforms, you can apply modifications
to the EAD files exported from ArchivesSpace.  Any XSLT transforms you
provide will be run immediately after the EAD record is exported from
ArchivesSpace, but *before* any Schematron or XSD validations.  This
allows your XSLT to clean up any common data issues prior to
validation.

As with the validations, you configure your XSLT transforms by adding
your `.xslt` file to the `exporter-app/config` directory, then adding
a reference to your `jobs.rb` file such as:

     :xslt_transforms => ['config/transform.xslt', 'config/another-transform.xslt'],

Transforms are run left to right, with the output of each transform
feeding into the next one as input.

### Before and After Hooks

Each `WeekdayJob` has a list of `:before_hooks` and `:after_hooks`
that are run at different points in the export process.  The exporter
app makes use of these for its own purposes (preparing git
directories, producing PDF files, committing to git, etc.), but you
can add your own hooks to inject your own custom behavior.  For
example, by adding a new `ShellRunner` instance to the list, you could
run a shell script that emailed you whenever an export job completed.

As the names would suggest, before hooks run prior to the export
process (at the point the job is started), while after hooks run once
the export has completed, and once the XSLT transforms and validations
have finished.

When running a script via `ShellRunner`, the shell script you provide
should return 0 on success, or anything else for failure.  If the
shell script returns a failure status, the export job will abort.

# Publishing to GitHub

Publishing to GitHub is the responsibility of the
`RepositoryMergeTask`, which takes the output from one or more EAD
export tasks, combines them into a single git repository and pushes
the result to GitHub.

## Merging the output from export jobs

Each job defined in `jobs.rb` produces a directory (a git repository)
containing the records that have been exported by that job.  For the
purposes of publishing records to GitHub, it is often desirable to
combine the output of one or more export jobs into a single repository
on GitHub.  For example, you might have one export job that exports
any manuscripts collections, and another job that exports music
collections, but you want these collections to appear merged into a
single GitHub repository.

To do this, we define a new job in `jobs.rb` that runs a
`RepositoryMergeTask`.  You can see an example of this in the sample
`jobs.rb` provided with the exporter-app: this combines the records of
the two ExportEADTask jobs into a single repository and pushes it up
to GitHub.  Generally you would want to configure the start and end
times for the `RepositoryMergeTask` so that it runs after the relevant
export tasks have finished.  If the merge task starts running while
the exports are still going, that's fine: it will just merge and
publish whatever is available and catch up when it next runs.

Note that, as the RepositoryMergeTask pushes to GitHub, you will
always have at least one of these tasks defined--even if you only have
a single export job.  Additionally, you are free to have as many
number of export tasks and merge tasks as you like, and you can
combine them in arbitrary ways to produce the outcome you need.

## Setting up GitHub deploy keys

When the merge task has finished merging the exported records, its
final step is to push the result to a GitHub repository.  To do this,
it needs to be configured with access to the GitHub repository that
will receive the records.  There are two ways to go about this:

  * You can put a GitHub username and password directory in the
    configuration file; or

  * You can set up SSH deploy keys in GitHub to give the exporter
    application the access it needs

For the username/password option, you can just supply your account
credentials when you specify the `:git_remote` URL:

     :git_remote => 'https://yourusername:yourpassword@github.com/yourusername/yourrepo.git',

If you want to use SSH keys, you will need to specify your
`:git_remote` URL like this:

     :git_remote => 'git@github.com:yourusername/yourrepo.git',

Next, create a new pair of SSH keys that you will need to add to
GitHub.  From a terminal:

     $ cd /path/to/exporter-app
     $ bin/generate_deploy_key.sh git_repository

Note that `git_repository` above should match the identifier of the
merge task in your `jobs.rb` (the example file uses `git_repository`).

You'll see that the `generate_deploy_key.sh` script prints some
instructions on how to import the newly created SSH key into GitHub.
Once you have done that, the application should be able to push to
your GitHub repository.
