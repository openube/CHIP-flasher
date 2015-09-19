import time
import subprocess
import os
import signal
from os import path
from kivy.clock import Clock
from functools import partial
from threading import Timer
import logging
log = logging.getLogger('flasher')

# calls a shell command
def call_and_return(instance, cmd, timeout=1):
	def update_progress_bar( dt ):
		progress = instance.get_progress()
		progress["value"] = progress["value"] + dt
		if progress["value"] >= progress["max"]:
			progress["value"] = progress["max"]

		instance.set_progress( progress["value"], progress["max"] )


	log.info('ENTER: call_and_return()')
	working_dir=path.dirname( path.dirname( path.realpath( __file__ ) ) )
	proc = subprocess.Popen( cmd, cwd=working_dir+"/tools", shell=False, preexec_fn=os.setsid )
	timer = Timer( timeout, os.killpg, [ proc.pid, signal.SIGTERM ] )
	returncode = None
	time_elapsed = 0
	try:
		timer.start()
		instance.set_progress( 0, timeout )
		Clock.schedule_interval( update_progress_bar, 1.0/60.0 )
		proc.communicate()
		proc.wait()
		returncode = proc.returncode
		log.info('error code='+str(proc.returncode))
		log.info('LEAVE: call_and_return()')
	finally:
		timer.cancel()
		Clock.unschedule( update_progress_bar )
		log.info('error code='+str(proc.returncode))
		log.info('LEAVE: call_and_return()')
		if proc.returncode < 0:
			log.info('Timeout occurred!')
		
		if proc.poll():
			log.error("Process " + str(proc.pid) + " is still running!")
		return returncode