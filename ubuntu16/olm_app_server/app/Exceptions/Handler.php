<?php

namespace App\Exceptions;

use Exception;
use Illuminate\Validation\ValidationException;
use Illuminate\Auth\Access\AuthorizationException;
use App\Devices\Exceptions\CommandTypeNotSupported;
use App\Devices\Exceptions\DeviceNotReadyException;
use App\Devices\Exceptions\ParametersInvalidException;
use App\Devices\Exceptions\DeviceNotConnectedException;
use App\Devices\Exceptions\DriverDoesNotExistException;
use App\Devices\Exceptions\ExperimentTimedOutException;
use Illuminate\Database\Eloquent\ModelNotFoundException;
use App\Devices\Exceptions\ExperimentCommandNotAvailable;
use Symfony\Component\HttpKernel\Exception\HttpException;
use App\Devices\Exceptions\ExperimentNotSupportedException;
use App\Devices\Exceptions\DeviceNotRunningExperimentException;
use Illuminate\Foundation\Exceptions\Handler as ExceptionHandler;
use App\Devices\Exceptions\DeviceAlreadyRunningExperimentException;

class Handler extends ExceptionHandler
{
    /**
     * A list of the exception types that should not be reported.
     *
     * @var array
     */
    protected $dontReport = [
        AuthorizationException::class,
        HttpException::class,
        ModelNotFoundException::class,
        ValidationException::class,
    ];

    protected $deviceExceptions = [
        DeviceAlreadyRunningExperimentException::class,
        DeviceNotConnectedException::class,
        DeviceNotReadyException::class,
        ParametersInvalidException::class,
        ExperimentTimedOutException::class,
        DriverDoesNotExistException::class,
        DeviceNotRunningExperimentException::class,
        ExperimentNotSupportedException::class,
        ExperimentCommandNotAvailable::class,
        CommandTypeNotSupported::class
    ];

    /**
     * Report or log an exception.
     *
     * This is a great spot to send exceptions to Sentry, Bugsnag, etc.
     *
     * @param  \Exception  $e
     * @return void
     */
    public function report(Exception $e)
    {
        parent::report($e);
    }

    /**
     * Render an exception into an HTTP response.
     *
     * @param  \Illuminate\Http\Request  $request
     * @param  \Exception  $e
     * @return \Illuminate\Http\Response
     */
    public function render($request, Exception $e)
    {
        if($this->isDeviceException($e)) {
            return $e->getResponse();
        }

        return parent::render($request, $e);
    }

    protected function isDeviceException(Exception $e) {
        foreach ($this->deviceExceptions as $type) {
            if($e instanceof $type) {
                return true;
            }
        }

        return false;
    }
}
