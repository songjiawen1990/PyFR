# -*- coding: utf-8 -*-

from pyfr.integrators.base import BaseIntegrator
from pyfr.util import proxylist


class BaseController(BaseIntegrator):
    def __init__(self, *args, **kwargs):
        super(BaseController, self).__init__(*args, **kwargs)

        # Current and minimum time steps
        self._dt = self._cfg.getfloat('time-integration', 'dt')
        self._dtmin = 0.1*self._dt

        # Bank index of solution
        self._idxcurr = 0

        # Event handlers for advance_to
        self.completed_step_handlers = proxylist([])

class NoneController(BaseController):
    controller_name = 'none'

    def __init__(self, *args, **kwargs):
        super(NoneController, self).__init__(*args, **kwargs)

    @property
    def _controller_needs_errest(self):
        return False

    def advance_to(self, t):
        if t < self.tcurr:
            raise ValueError('Advance time is in the past')

        while (t - self.tcurr) > self._dtmin:
            # Decide on the time step
            dt = min(t - self.tcurr, self._dt)

            # Take the step
            self._idxcurr = self.step(self.tcurr, dt)

            # Increment the time
            self.tcurr += dt

            # Fire off any event handlers
            self.completed_step_handlers(self)

        # Return the solution matrices
        return self._meshp.ele_scal_upts(self._idxcurr)