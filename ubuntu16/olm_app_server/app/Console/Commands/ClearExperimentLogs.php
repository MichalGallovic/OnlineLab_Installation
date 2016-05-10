<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\File;

class ClearExperimentLogs extends Command
{
    /**
     * The name and signature of the console command.
     *
     * @var string
     */
    protected $signature = 'experiment:logs:clear';

    /**
     * The console command description.
     *
     * @var string
     */
    protected $description = 'Clears experiment logs';

    /**
     * Create a new command instance.
     *
     * @return void
     */
    public function __construct()
    {
        parent::__construct();
    }

    /**
     * Execute the console command.
     *
     * @return mixed
     */
    public function handle()
    {
        $deviceLogsPath = storage_path("logs/devices");

        if(File::exists($deviceLogsPath)) {
            $files = File::allFiles($deviceLogsPath);
            File::delete($files);
        } else {
            File::makeDirectory($deviceLogsPath, 0755, true);
        }
    }
}
