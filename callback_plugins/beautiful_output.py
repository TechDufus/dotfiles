# -*- coding: utf-8 -*-

# MIT License
#
# Copyright (c) 2019 Thiago Alves
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

"""A clean and opinionated output callback plugin.

The goal of this plugin is to consolidated Ansible's output in the style of
LINUX/UNIX startup logs, and use unicode symbols to display task status.

This Callback plugin is intended to be used on playbooks that you have
to execute *"in-person"*, since it does always output to the screen.

In order to use this Callback plugin, you should add this Role as a dependency
in your project, and set the ``stdout_callback`` option on the
:file:`ansible.cfg file::

    stdout_callback = beautiful_output

"""

# Make coding more python3-ish
from __future__ import absolute_import, division, print_function

__metaclass__ = type

DOCUMENTATION = """---
    callback: beautiful_output
    type: stdout
    author: Thiago Alves <thiago@rapinialves.com>
    short_description: a clean, condensed, and beautiful Ansible output
    version_added: 2.8
    description:
      - >-
        Consolidated Ansible output in the style of LINUX/UNIX startup
        logs, and use unicode symbols to organize tasks.
    extends_documentation_fragment:
      - default_callback
    requirements:
      - set as stdout in configuration
"""

import json
import locale
import os
import re
import textwrap
import yaml

from ansible import constants as C
from ansible import context
from ansible.executor.task_result import TaskResult
from ansible.module_utils._text import to_text, to_bytes
from ansible.module_utils.common._collections_compat import Mapping
from ansible.parsing.utils.yaml import from_yaml
from ansible.plugins.callback import CallbackBase
from ansible.template import Templar
from ansible.utils.color import colorize, hostcolor, stringc
from ansible.vars.clean import strip_internal_keys, module_response_deepcopy
from ansible.vars.hostvars import HostVarsVars
from collections import OrderedDict
try:
    from collections.abc import Sequence
except:
    from collections import Sequence
from numbers import Number
from os.path import basename, isdir
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler, EVENT_TYPE_CREATED

_symbol = {
    "success": to_text("✔"),
    "warning": to_text("⚠"),
    "failure": to_text("✘"),
    "dead": to_text("✝"),
    "yaml": to_text("🅨"),
    "retry": to_text("️↻"),
    "loop": to_text("∑"),
    "arrow_right": to_text("➞"),
    "skip": to_text("⤼"),
    "flag": to_text("⚑"),
}  # type: Dict[str,str]
""":obj:`dict` of :obj:`str` to :obj:`str`: A dictionary of symbols to be used
when the Callback needs to display a symbol on the screen.
"""

_session_title = {
    "msg": "Message",
    "stdout": "Output",
    "stderr": "Error output",
    "module_stdout": "Module output",
    "module_stderr": "Module error output",
    "rc": "Return code",
    "changed": "Environment changed",
    "_ansible_no_log": "Omit logs",
    "use_stderr": "Use STDERR to output",
}  # type: Dict[str,str]
""":obj:`dict` of :obj:`str` to :obj:`str`: A dictionary of terms used as
section title when displayin the output of a command.
"""

_session_order = OrderedDict(
    [
        ("_ansible_no_log", 3),
        ("use_stderr", 4),
        ("msg", 1),
        ("stdout", 1),
        ("module_stdout", 1),
        ("stderr", 1),
        ("module_stderr", 1),
        ("rc", 3),
        ("changed", 3),
    ]
)
""":obj:`dict` of :obj:`str` to :obj:`str`: A dictionary representing the
display an order in wich sections should be displayed to user.
"""

ansi_escape = re.compile(
    r"""
    \x1B    # ESC
    [@-_]   # 7-bit C1 Fe
    [0-?]*  # Parameter bytes
    [ -/]*  # Intermediate bytes
    [@-~]   # Final byte
""",
    re.VERBOSE,
)
""":regexp:`Pattern`: A regular expression that can match any ANSI escape
sequence in a string.
"""


def symbol(key, color=None):  # type: (str, str) -> str
    """Helper function that returns an Unicode character based on the given
    ``key``. This function also colorize the returned string using the
    :func:`~ansible.utils.color.stringc` function, depending on the value
    passed to `color`.

    Args:
        key (:obj:`str`): One of the keys used to define the dictionary
            :const:`~beautiful_output._symbol`.
        color (:obj:`str`, optional): a string representing the color that
            should be used to diplay the given symbol
    
    Returns:
        :obj:`str`: A unicode character representing a symbol for the given
        ``key``.
    """
    output = _symbol.get(key, to_text(":{0}:").format(key))
    if not color:
        return output
    return stringc(output, color)


def iscollection(obj):
    """Helper method to check if a given object is not only a Squence, but also
    **not** any kind of string.
    
    Args:
        obj (object): The object used on the validation.
    
    Returns:
        bool: True if the object is a collection and False otherwise.
    """
    return isinstance(obj, Sequence) and not isinstance(obj, basestring)


def stringtruncate(
    value,
    color="normal",
    width=0,
    justfn=None,
    fillchar=" ",
    truncate_placeholder="[...]",
):
    """Truncates a giving string using the configuration passed as arguments to
    this function.
    
    Args:
        value (:obj:`str` or int): A value to be truncated if it has more
            characters than is allowed.
        color (:obj:`str`, optional): A string representing a color for Ansible.
            If this color is ``None``, no color will be used. Defaults to None.
        width (int, optional): The limits of characters allowed for the giving
            ``value``. If 0 is given, no truncation happens. Defaults to 0.
        justfn (:func:`Callable`, optional): A function to do the justification
            of the text. Defaults to :func:`str.rjust` if the type of ``value``
            is integer and :func:`str.ljust` otherwise.
        fillchar (:obj:`str`, optional): The character used to fill the space up
            to ``width`` after (or before) the ``value`` content. Defaults to
            " ".
        truncate_placeholder (:obj:`str`, optional): The text used to represents
            the truncation. Defaults to "[...]".
    
    Returns:
        The original string truncated to ``width`` and aligned according to
        ``justfn``.
    """
    if not value:
        return fillchar * width

    if not justfn:
        justfn = str.rjust if isinstance(value, int) else str.ljust

    if isinstance(value, int):
        value = to_text("{:n}").format(value)

    truncsize = len(truncate_placeholder)
    do_not_trucate = len(value) <= width or width == 0
    truncated_width = width - truncsize

    return stringc(
        to_text(justfn(str(value), width))
        if do_not_trucate
        else to_text("{0}{1}".format(
            value[:truncated_width] if justfn == str.ljust else truncate_placeholder,
            truncate_placeholder if justfn == str.ljust else value[truncated_width:],
        )),
        color,
    )


def dictsum(totals, values):
    """Given two dictionaries of ``int`` values, this method will sum the
    value in ``totals`` with values in ``values``.

    If a key in ``values`` does not exist in ``totals``, that key will be
    added to it, and its initial value will be the same as in ``values``.

    Note:
        The type of the keys in the dictionaries are irrelevant, and this
        method will re-use anything that is used there.
    
    Args:
        totals (:obj:`dict` of :obj:`object` to int): The total cached
            from previous calls of this functions.
        values (:obj:`dict` of :obj:`object` to int): The dictionary of
            values used to sum up the totals.

    Exemple:
        >>> dict1 = {"key1": 10, "key2": 20, "key3": 30}
        >>> dict2 = {"key1": 5, "key2": 10, "key3": 15}
        >>> dict3 = {"key1": 1, "key2": 2, "key3": 3}
        >>> totals = {}
        >>> dictsum(totals, dict1)
        >>> totals
        {"key1": 10, "key2": 20, "key3": 30}
        >>> dictsum(totals, dict2)
        >>> totals
        {"key1": 15, "key2": 30, "key3": 45}
        >>> dictsum(totals, dict3)
        >>> totals
        {"key1": 16, "key2": 32, "key3": 48}
    """
    for key, value in values.items():
        if key not in totals:
            totals[key] = value
        else:
            totals[key] += value


class CallbackModule(CallbackBase, FileSystemEventHandler):
    """The Callback plugin class to produce clean outputs.

    This class handles all Ansible callbacks that generate text on the output.
    It follows the new user configuration variables like
    :data:`~ansible.constants.DISPLAY_ARGS_TO_STDOUT` and
    :data:`~ansible.constants.DISPLAY_SKIPPED_HOSTS`, and it wraps lines at
    column ``80`` to make it possible to read the output on any monitor.
    
    In addition to that, the ``beautiful_output`` plugin implements a crud
    version of a Bus to allow other plugins to flush the output when necessary.

    Normally, in order to hide task not executed, the ``beautiful_output``
    plugin will delay printing the task's title until it knows there is anything
    to print. On certain conditions, an action plugin can output an information
    to the user, and without the Bus mechanism, the action plugin output would
    show up before the task title is printed, which would feel like the action
    plugin output belongs to the previous task.

    In order to flush the output on these scenarios, a plugin needs to write a
    file to a location where the ``beautiful_output`` plugin is observing. At
    this point, the Callback plugin will flush any outstanding text, and the
    other plugin can proceed with its own task.

    Args:
        display (:obj:`ansible.utils.display.Display`, optional): Holds the
            display to be used to print outputs with this callback.

    Attributes:
        CALLBACK_VERSION (:obj:`decimal`): A class attribute that holds the
            last version of Ansible Callback API that can use this plugin.
        CALLBACK_TYPE (:obj:`str`): The type of callback this plugin is
            implementing.
        CALLBACK_NAME (:obj:`str`): The name of this plugin.
        BUS_DIR (:obj:`str`): The path where the ``beautiful_stdout`` plugin
            will observe for files to trigger a flush.
        delegated_vars (:obj:`dict` of :obj:`str` to :obj:`str`): This
            dictionaire is used to store the variables used by a task when it
            delegated to a different host. Mostly, we only need to know the
            host name where our task was delegated to. Defaults to ``None``.
        _item_processed (:obj:`bool`): A flag indicating if an item from a task
            was already processed and printed. This is to allow us to print a
            header before start printin all the items from a task. Defaults to
            ``False``.
        _current_play (:obj:`~ansible.playbook.play.Play`): This attribute holds
            the current play being executed on this playbook. Defaults to
            ``None``.
        _current_host (:obj:`str`): The host where a task is being executed at
            the moment we access this attribute. If this attribute is ``None``,
            this means that at this moment there is no task being executed on
            any host. Defaults to ``None``.
        _task_name_buffer (:obj:`str`): This attribute holds the text that
            should be printed when a task is being executed. Defaults to
            ``None``.

    See Also:
        - :class:`ansible.plugins.callback.CallbackBase`
        - :class:`watchdog.events.FileSystemEventHandler`
        - `Ansible Callback documentation`_

    References:
        - `Ansible developping plugins documentation`_
        - `Ansible Callback plugins from Ansible Core`_


    .. _Ansible Callback documentation:
        https://docs.ansible.com/ansible/latest/plugins/callback.html    
    .. _Ansible developping plugins documentation:
        https://docs.ansible.com/ansible/latest/dev_guide/developing_plugins.html#callback-plugins
    .. _Ansible Callback plugins from Ansible Core:
        https://github.com/ansible/ansible/tree/devel/lib/ansible/plugins/callback
    """

    CALLBACK_VERSION = 2.0
    CALLBACK_TYPE = "stdout"
    CALLBACK_NAME = "beautiful_output"
    BUS_DIR = "%s/beautiful-output-bus" % C.DEFAULT_LOCAL_TMP

    def __init__(self, display=None):
        CallbackBase.__init__(self, display)
        self.delegated_vars = None
        self._item_processed = False
        self._current_play = None
        self._current_host = None
        self._task_name_buffer = None

    def display(self, msg, color=None, stderr=False):
        """Helper method to display text on the screen.

        This method is a thin wrapper aroung the real
        :meth:`~ansible.utils.display.Display.display` method from the Ansible
        :class:`~ansible.utils.display.Display` class.

        Any ``msg`` that is displayed with this method, will be displayed
        without any changes on the screen, and will have all the ANSI escape
        sequences stripped before displaying it on the logs.
        
        Args:
            msg (:obj:`str`): The message to be displayed.
            color (:obj:`str`, optional): A string representing a color on the
                Ansible Display system. Defaults to None.
            stderr (bool, optional): Flag indicating that the ``msg``should be
                displayed on the :data:`stderr` stream. Defaults to False.
        """
        self._display.display(msg=msg, color=color, stderr=stderr, screen_only=True)
        self._display.display(
            msg=ansi_escape.sub("", msg), stderr=stderr, log_only=True
        )

    def v2_playbook_on_start(self, playbook):
        """Displays the Playbook report Header when Ansible starst running it.

        The content displayed will depend on the options used to run the
        playbook, as well as the options configured in the :file:`ansible.cfg`
        file.

        It will always show which playbook it is running and if it is running
        in check mode.

        It will display all arguments used to run the given ``playbook` if it
        is running in verbose mode (`-vvv`), the ``display_args_to_stdout``
        option in the :file:`ansible.cfg` file, or if the
        ``ANSIBLE_DISPLAY_ARGS_TO_STDOUT`` environment variable is set

        It will display a tag line, only if the CLI arguments are **not**
        displayed, since the tags used to filters which tasks to run are passed
        in the command line as arguments
        
        Args:
            playbook (:obj:`~ansible.playbook.Playbook`): The running playbook.

        See Also:
            - :meth:`_display_cli_arguments`
            - :meth:`_display_tag_strip`

        Note:
            Overrides the
            :meth:`~ansible.plugins.callback.CallbackBase.v2_playbook_on_start`
            method from the :class:`~ansible.plugins.callback.CallbackBase`
            class.
        """
        playbook_name = to_text("{0} {1}").format(
            symbol(to_text("yaml"), C.COLOR_HIGHLIGHT),
            stringc(basename(playbook._file_name), C.COLOR_HIGHLIGHT),
        )
        if (
            "check" in context.CLIARGS
            and bool(context.CLIARGS["check"])
            and not self._is_run_verbose(verbosity=3)
            and not C.DISPLAY_ARGS_TO_STDOUT
        ):
            playbook_name = to_text("{0} (check mode)").format(playbook_name)

        self.display(to_text("\nExecuting playbook {0}").format(playbook_name))

        # show CLI arguments
        if self._is_run_verbose(verbosity=3) or C.DISPLAY_ARGS_TO_STDOUT:
            self._display_cli_arguments()
        else:
            self._display_tag_strip(playbook)
        self.display(to_text("\n"))

    def v2_playbook_on_no_hosts_matched(self):
        """Display a warning when there is no hosts available.

        Note:
            Overrides the
            :meth:`~ansible.plugins.callback.CallbackBase.v2_playbook_on_no_hosts_matched`
            method from the :class:`~ansible.plugins.callback.CallbackBase`
            class.
        """
        self.display(
            "  %s No hosts found!" % symbol("warning", "bright yellow"),
            color=C.COLOR_DEBUG,
        )

    def v2_playbook_on_no_hosts_remaining(self):
        """Display an error when one or more hosts that were alive when the
        playbook start running are not reachable anymore.

        Note:
            Overrides the
            :meth:`~ansible.plugins.callback.CallbackBase.v2_playbook_on_no_hosts_remaining`
            method from the :class:`~ansible.plugins.callback.CallbackBase`
            class.
        """
        self.display(
            "  %s Ran out of hosts!" % symbol("warning", "bright red"),
            color=C.COLOR_ERROR,
        )

    def v2_playbook_on_play_start(self, play):
        """Displays a banner with the play name and the hosts used in this
        play.

        This method might be called multimple times during the execution of a
        playbook, and it will not always have the play changed. Due to this
        fact, we short-circuit the method to not do anything if the play used
        to display the banner is the same as the one used on the last time the
        method was called.
        
        Args:
            play (:obj:`~ansible.playbook.play.Play`): the current play being
                executed on this playbook.

        Note:
            Overrides the
            :meth:`~ansible.plugins.callback.CallbackBase.v2_playbook_on_play_start`
            method from the :class:`~ansible.plugins.callback.CallbackBase`
            class.
        """
        if self._current_play:
            self._current_play = play
            return
        self._current_play = play
        name = play.get_name().strip()
        if name:
            self.display(
                to_text("[PLAY: {0}]").format(stringc(name, C.COLOR_HIGHLIGHT)).center(91, "-")
            )
        else:
            self.display("[PLAY]".center(80, "-"))

        if play.hosts:
            self.display("Hosts:")
            for host in play.hosts:
                self.display(to_text("  - {0}").format(stringc(host, C.COLOR_HIGHLIGHT)))
            self.display(to_text("-") * 80)

    def v2_playbook_on_task_start(self, task, is_conditional):
        """Displays a title for the giving ``task`.
        
        Args:
            task (:obj:`~ansible.playbook.task.Task`): The task to have its
                title printed in the console.
            is_conditional: This attribute is ignored in this callback.

        See Also:
            :meth:`_display_task_name`

        Note:
            Overrides the
            :meth:`~ansible.plugins.callback.CallbackBase.v2_playbook_on_task_start`
            method from the :class:`~ansible.plugins.callback.CallbackBase`
            class.
        """
        self._display_task_name(task)

    def v2_playbook_on_handler_task_start(self, task):
        """Displays a title for the giving ``task`, marking it as a handler
        task.
        
        Args:
            task (:obj:`~ansible.playbook.task.Task`): The task to have its
                title printed in the console.

        See Also:
            :meth:`_display_task_name`

        Note:
            Overrides the
            :meth:`~ansible.plugins.callback.CallbackBase.v2_playbook_on_handler_task_start`
            method from the :class:`~ansible.plugins.callback.CallbackBase`
            class.
        """
        self._display_task_name(task, is_handler=True)

    def v2_runner_retry(self, result):
        """Displays the retrying steps Ansible is doing to make the task run
        on the host.
        
        Args:
            result (:obj:`~ansible.executor.task_result.TaskResult`): The result
                object representing the previous attempt to run the task.

        Note:
            Overrides the
            :meth:`~ansible.plugins.callback.CallbackBase.v2_runner_retry`
            method from the :class:`~ansible.plugins.callback.CallbackBase`
            class.
        """
        msg = "  ️%s Retrying... (%d of %d)" % (
            symbol("retry"),
            result._result["attempts"],
            result._result["retries"],
        )
        if self._is_run_verbose(result, 2):
            # All result keys stating with _ansible_ are internal, so remove them from the result before we output anything.
            abridged_result = strip_internal_keys(
                module_response_deepcopy(result._result)
            )
            abridged_result.pop("exception", None)

            if not self._is_run_verbose(verbosity=3):
                abridged_result.pop("invocation", None)
                abridged_result.pop("diff", None)

            msg += "Result was: %s" % CallbackModule.dump_value(abridged_result)
        self.display(msg, color=C.COLOR_DEBUG)

    def v2_runner_on_start(self, host, task):
        """Caches the giving ``host`` object to be easily accessible during the
        evaluation of a task display.

        Args:
            host (:obj:`~ansible.inventory.host.Host`): The host that will run
                the giving ``task``.
            task (:obj:`~ansible.playbook.task.Task`): The task that will be
                ran on the giving ``host``.

        Note:
            Overrides the
            :meth:`~ansible.plugins.callback.CallbackBase.v2_runner_on_start`
            method from the :class:`~ansible.plugins.callback.CallbackBase`
            class.
        """
        self._current_host = host

    def v2_runner_on_ok(self, result):
        """Displays the result of a task run.

        This method will also be called every time an **item**, on a loop task,
        is processed.
        
        Args:
            result (:obj:`~ansible.executor.task_result.TaskResult`): The result
                object representing the execution of a task.

        See Also:
            - :meth:`_preprocess_result`
            - :meth:`changed_artifacts`
            - :meth:`_process_result_output`

        Note:
            Overrides the
            :meth:`~ansible.plugins.callback.CallbackBase.v2_runner_on_ok`
            method from the :class:`~ansible.plugins.callback.CallbackBase`
            class.
        """
        if self._item_processed:
            return

        self._preprocess_result(result)
        msg, display_color = CallbackModule.changed_artifacts(result, "ok", C.COLOR_OK)
        task_result = self._process_result_output(result, msg, symbol("success"))
        self.display(task_result, display_color)

    def v2_runner_on_skipped(self, result):
        """If the you configured Ansible to display skipped hosts, this method
        will display the task and information that it was skipped.

        Args:
            result (:obj:`~ansible.executor.task_result.TaskResult`): The result
                object representing the execution of a task.

        See Also:
            - :meth:`_preprocess_result`
            - :meth:`_process_result_output`

        Note:
            Overrides the
            :meth:`~ansible.plugins.callback.CallbackBase.v2_runner_on_skipped`
            method from the :class:`~ansible.plugins.callback.CallbackBase`
            class.
        """
        if C.DISPLAY_SKIPPED_HOSTS:
            self._preprocess_result(result)
            task_result = self._process_result_output(result, "skipped", symbol("skip"))
            self.display(task_result, C.COLOR_SKIP)
            pass
        else:
            self.outlines = []

    def v2_runner_on_failed(self, result, ignore_errors=False):
        """When a task fails, this method is called to display information
        about the error.

        Args:
            result (:obj:`~ansible.executor.task_result.TaskResult`): The result
                object representing the execution of a task.

        See Also:
            - :meth:`_preprocess_result`
            - :meth:`_process_result_output`

        Note:
            Overrides the
            :meth:`~ansible.plugins.callback.CallbackBase.v2_runner_on_failed`
            method from the :class:`~ansible.plugins.callback.CallbackBase`
            class.
        """
        if self._item_processed:
            return

        self._preprocess_result(result)
        status = "ignored" if ignore_errors else "failed"
        color = C.COLOR_SKIP if ignore_errors else C.COLOR_ERROR
        task_result = self._process_result_output(result, status, symbol("failure"))
        self.display(task_result, color)

    def v2_runner_on_unreachable(self, result):
        """When a host becames *unreachable* before the execution of its task,
        this method will display information about the unreachability.

        Args:
            result (:obj:`~ansible.executor.task_result.TaskResult`): The result
                object representing the execution of a task.

        See Also:
            - :meth:`_preprocess_result`
            - :meth:`_process_result_output`

        Note:
            Overrides the
            :meth:`~ansible.plugins.callback.CallbackBase.v2_runner_on_unreachable`
            method from the :class:`~ansible.plugins.callback.CallbackBase`
            class.
        """
        self._flush_display_buffer()
        task_result = self._process_result_output(result, "unreachable", symbol("dead"))
        self.display(task_result, C.COLOR_UNREACHABLE)

    def v2_runner_item_on_ok(self, result):
        """Displays the result of an item task run.

        Args:
            result (:obj:`~ansible.executor.task_result.TaskResult`): The result
                object representing the execution of a task.

        See Also:
            - :meth:`_preprocess_result`
            - :meth:`changed_artifacts`
            - :meth:`_process_item_result_output`

        Note:
            Overrides the
            :meth:`~ansible.plugins.callback.CallbackBase.v2_runner_on_ok`
            method from the :class:`~ansible.plugins.callback.CallbackBase`
            class.
        """
        self._preprocess_result(result)
        status, display_color = CallbackModule.changed_artifacts(
            result, "ok", C.COLOR_OK
        )
        task_result = self._process_item_result_output(
            result, status, symbol("success")
        )
        self.display(task_result, display_color)

    def v2_runner_item_on_skipped(self, result):
        """If the you configured Ansible to display skipped hosts, this method
        will display a task item and information that it was skipped.

        Args:
            result (:obj:`~ansible.executor.task_result.TaskResult`): The result
                object representing the execution of a task.

        See Also:
            - :meth:`_preprocess_result`
            - :meth:`_process_item_result_output`

        Note:
            Overrides the
            :meth:`~ansible.plugins.callback.CallbackBase.v2_runner_on_skipped`
            method from the :class:`~ansible.plugins.callback.CallbackBase`
            class.
        """
        if C.DISPLAY_SKIPPED_HOSTS:
            self._preprocess_result(result)
            task_result = self._process_item_result_output(
                result, "skipped", symbol("skip")
            )
            self.display(task_result, C.COLOR_SKIP)
        else:
            self.outlines = []

    def v2_runner_item_on_failed(self, result):
        """When an intem on a task fails, this method is called to display
        information about the failure.

        Args:
            result (:obj:`~ansible.executor.task_result.TaskResult`): The result
                object representing the execution of a task.

        See Also:
            - :meth:`_preprocess_result`
            - :meth:`_process_item_result_output`

        Note:
            Overrides the
            :meth:`~ansible.plugins.callback.CallbackBase.v2_runner_item_on_failed`
            method from the :class:`~ansible.plugins.callback.CallbackBase`
            class.
        """
        self._flush_display_buffer()
        task_result = self._process_item_result_output(
            result, "failed", symbol("failure")
        )
        self.display(task_result, C.COLOR_ERROR)

    def v2_playbook_on_stats(self, stats):
        """When the execution of a playbook finishes, this method is called to
        display an execution summary.

        It also displays an aggregate total for all executions.

        Note:
            Overrides the
            :meth:`~ansible.plugins.callback.CallbackBase.v2_playbook_on_stats`
            method from the :class:`~ansible.plugins.callback.CallbackBase`
            class.
        """
        self.display(to_text("{0}\n\n").format("-" * 80))
        totals = {
            "ok": 0,
            "changed": 0,
            "unreachable": 0,
            "failures": 0,
            "rescued": 0,
            "ignored": 0,
        }

        self._display_summary_table_row(
            ("Hosts", C.COLOR_VERBOSE, 30),
            ("Success", C.COLOR_VERBOSE, 7),
            ("Changed", C.COLOR_VERBOSE, 7),
            ("Dark", C.COLOR_VERBOSE, 7),
            ("Failed", C.COLOR_VERBOSE, 7),
            ("Rescued", C.COLOR_VERBOSE, 7),
            ("Ignored", C.COLOR_VERBOSE, 7),
        )
        self._display_summary_table_separator("=")

        hosts = sorted(stats.processed.keys())
        for host_name in hosts:
            host_summary = stats.summarize(host_name)
            dictsum(totals, host_summary)
            self._display_summary_table_row(
                (host_name, C.COLOR_HIGHLIGHT, 30),
                (host_summary["ok"], C.COLOR_OK, 7),
                (host_summary["changed"], C.COLOR_CHANGED, 7),
                (host_summary["unreachable"], C.COLOR_UNREACHABLE, 7),
                (host_summary["failures"], C.COLOR_ERROR, 7),
                (host_summary["rescued"], C.COLOR_OK, 7),
                (host_summary["ignored"], C.COLOR_WARN, 7),
            )

        self._display_summary_table_separator("-")
        self._display_summary_table_row(
            ("Totals", C.COLOR_VERBOSE, 30),
            (totals["ok"], C.COLOR_OK, 7),
            (totals["changed"], C.COLOR_CHANGED, 7),
            (totals["unreachable"], C.COLOR_UNREACHABLE, 7),
            (totals["failures"], C.COLOR_ERROR, 7),
            (totals["rescued"], C.COLOR_OK, 7),
            (totals["ignored"], C.COLOR_WARN, 7),
        )

    def _handle_exception(self, result, use_stderr=False):
        """When an exception happen during the execution of a playbook, this
        method is called to display information about the crash.
        
        Args:
            result (:obj:`~ansible.executor.task_result.TaskResult`): The result
                object representing the execution of a task.
            use_stderr (bool, optional): Flag indicating if this exception
                should be printed using the ``stderr`` stream. Defaults to
                ``False``.
        """
        if "exception" in result:
            result["use_stderr"] = use_stderr
            msg = "An exception occurred during task execution. "
            if not self._is_run_verbose(verbosity=3):
                # extract just the actual error message from the exception text

                error = result["exception"].strip().split("\n")[-1]
                msg += "To see the full traceback, use -vvv. The error was: %s" % error
            elif "module_stderr" in result:
                if result["exception"] != result["module_stderr"]:
                    msg = "The full traceback is:\n" + result["exception"]
                del result["exception"]
            result["stderr"] = msg

    def _is_run_verbose(self, result=None, verbosity=0):
        """Verify if the current run is verbose (should display information)
        respecting the given ``verbosity``.
        
        Args:
            result (:obj:`~ansible.executor.task_result.TaskResult, optional):
                The task result to be considered when checking verbosity.
                Defaults to None.
            verbosity (int, optional): The verbosity level that this method
                will check against. Defaults to 0.
        
        Returns:
            bool: True if the display verbosity cresses the treshold defined by
                the argument ``verbosity``, False otherwise.
        """
        result = {} if not result else result._result
        return (
            self._display.verbosity >= verbosity or "_ansible_verbose_always" in result
        ) and "_ansible_verbose_override" not in result

    def _display_cli_arguments(self, indent=2):
        """Display all arguments passed to Ansible in the command line.
        
        Args:
            indent (int, optional): Number of spaces to indent the whole
                arguments block. Defaults to 2.
        """
        if context.CLIARGS.get("args"):
            self.display(
                to_text("{0}Positional arguments: {1}").format(
                    " " * indent, ", ".join(context.CLIARGS["args"])
                ),
                color=C.COLOR_VERBOSE,
            )

        for arg, val in {
            key: value
            for key, value in context.CLIARGS.items()
            if key != "args" and value
        }.items():
            if iscollection(val):
                self.display(to_text("{0}{1}:").format(" " * indent, arg), color=C.COLOR_VERBOSE)
                for v in val:
                    self.display(
                        to_text("{0}- {1}").format(" " * (indent + 2), v), color=C.COLOR_VERBOSE
                    )
            else:
                self.display(
                    to_text("{0}{1}: {2}").format(" " * indent, arg, val), color=C.COLOR_VERBOSE
                )

    def _get_tags(self, playbook):
        """Returns a collection of tags that will be associated with all tasks
        runnin during this session.

        This means that it will collect all the tags available in the giving
        ``playbook``, and filter against the tags passed to Ansible in the
        command line.
        
        Args:
            playbook (:obj:`~ansible.playbook.Playbook`): The playbook where to
                look for tags.
        
        Returns:
            :obj:`list` of :obj:`str`: A sorted list of all tags used in this
            run.
        """
        tags = set()
        for play in playbook.get_plays():
            for block in play.compile():
                blocks = block.filter_tagged_tasks({})
                if blocks.has_tasks():
                    for task in blocks.block:
                        tags.update(task.tags)
        if "tags" in context.CLIARGS:
            requested_tags = set(context.CLIARGS["tags"])
        else:
            requested_tags = {"all"}
        if len(requested_tags) > 1 or next(iter(requested_tags)) != "all":
            tags = tags.intersection(requested_tags)
        return sorted(tags)

    def _display_tag_strip(self, playbook, width=80):
        """Displays a line of tags present in the given ``playbook``
        intersected with the tags given to Ansible in the command line.

        If the line is bigger than ``width`` characters, it will wrap the tag
        line before it cross the treshold.

        To make the tag line be more aesthetic pleasant, it will be displayed
        with a blank line before and after each line used.
        
        Args:
            playbook (:obj:`~ansible.playbook.Playbook`): The playbook where to
                look for tags.
            width (int): How many characters can be used in a single line.
                Defaults to 80.
        """
        tags = self._get_tags(playbook)
        tag_strings = ""
        total_len = 0
        first_item = True
        for tag in sorted(tags):
            if not first_item:
                if total_len + len(tag) + 5 > width:
                    tag_strings += to_text("\n\n  {0} {1} {2} {3}").format(
                        "\x1b[6;30;47m", symbol("flag"), tag, "\x1b[0m"
                    )
                    total_len = len(tag) + 6
                    first_item = True
                else:
                    tag_strings += to_text(" {0} {1} {2} {3}").format(
                        "\x1b[6;30;47m", symbol("flag"), tag, "\x1b[0m"
                    )
                    total_len += len(tag) + 5
            else:
                first_item = False
                tag_strings += to_text("  {0} {1} {2} {3}").format(
                    "\x1b[6;30;47m", symbol("flag"), tag, "\x1b[0m"
                )
                total_len = len(tag) + 6
        self.display("\n")
        self.display(tag_strings)

    def _get_task_display_name(self, task):
        """Caches the giving ``task`` name if it is not an include task.
        
        Args:
            task (:obj:`~ansible.playbook.task.Task`): The task object that
                will be analyzed.
        """
        self.task_display_name = None
        display_name = task.get_name().strip().split(" : ")

        task_display_name = display_name[-1]
        if task_display_name.startswith("include"):
            return
        else:
            self.task_display_name = task_display_name

    def _preprocess_result(self, result):
        """Check the result object for errors or warning. It also make sure
        that the task title buffer is flushed and displayed to the user.
        
        Args:
            result (:obj:`~ansible.executor.task_result.TaskResult`): The result
                object representing the execution of a task.

        See Also:
            - :meth:`_flush_display_buffer`
            - :meth:`_handle_exception`
            - :meth:`_handle_warnings`
        """
        self.delegated_vars = result._result.get("_ansible_delegated_vars", None)
        self._flush_display_buffer()
        self._handle_exception(result._result)
        self._handle_warnings(result._result)

    def _get_host_string(self, result, prefix=""):
        """Retrieve the host from the giving ``result``.
        
        Args:
            result (:obj:`~ansible.executor.task_result.TaskResult`): The result
                object representing the execution of a task.
            prefix (:obj:`str`, optional): A prefix added to the host name.
                Defaults to "".
        
        Returns:
            A formatted version of the host that generated the ``result``.
        """
        task_host = to_text("{0}{1}").format(prefix, result._host.get_name())
        if self.delegated_vars:
            task_host += to_text(" {0} {1}{2}").format(
                symbol("arrow_right"), prefix, self.delegated_vars["ansible_host"]
            )
        return task_host

    def _process_result_output(self, result, status, symbol_char="", indent=2):
        """Returns the result converted to string.

        Each key in the ``result._result`` is considered a session for the
        purpose of this method. All sessions have their content indented related
        to the session title.

        If a session verbosity (found on the :const:`_session_order` dictionary)
        doesnot cross the treshold for this playbook, it will not be shown.

        This method also converts all session titles that are present in the
        :const:`` dictionary, to their string representation. The rest of the
        titles are simply capitalized for aestetics purpose.
        
        Args:
            result (:obj:`~ansible.executor.task_result.TaskResult`): The result
                object representing the execution of a task.
            status (:obj:`str`): The status representing this ourput (e.g. "ok",
                "changed", "failed").
            symbol_char (:obj:`str`, optional): An UTF-8 character to be used as
                a symbol_char in the beginning of the output. Defaults to "".
            indent (int, optional): How many character the text generated from
                the ``result`` should be indended to. Defaults to 2.
        
        Returns:
            :obj:`str`: A formated version of the giving ``result``.
        """
        task_host = self._get_host_string(result)

        task_result = to_text("{0}{1}{2} [{3}]").format(
            " " * indent,
            symbol_char + " " if symbol_char else "",
            task_host,
            status.upper(),
        )

        for key, verbosity in _session_order.items():
            if (
                key in result._result
                and result._result[key]
                and self._is_run_verbose(result, verbosity)
            ):
                task_result += self.reindent_session(
                    _session_title.get(key, key), result._result[key], indent + 2
                )

        for title, text in result._result.items():
            if title not in _session_title and text and self._is_run_verbose(result, 2):
                task_result += self.reindent_session(
                    title.replace("_", " ").replace(".", " ").capitalize(),
                    text,
                    indent + 2,
                )

        return task_result

    def _process_item_result_output(self, result, status, symbol_char="", indent=2):
        """Displays the given ``result`` of an item task.

        This method is a simplified version of the
        :meth:`_process_result_output` method where no sessions are printed.
        
        Args:
            result (:obj:`~ansible.executor.task_result.TaskResult`): The result
                object representing the execution of a task.
            status (:obj:`str`): The status representing this ourput (e.g. "ok",
                "changed", "failed").
            symbol_char (:obj:`str`, optional): An UTF-8 character to be used as
                a symbol_char in the beginning of the output. Defaults to "".
            indent (int, optional): How many character the text generated from
                the ``result`` should be indended to. Defaults to 2.
        
        Returns:
            :obj:`str`: A formated version of the giving ``result``.
        """
        if not self._item_processed:
            self._item_processed = True
            self.display(to_text("{0}{1} Items:").format(" " * indent, symbol("loop")))

        item_name = self._get_item_label(result._result)
        if isinstance(item_name, dict):
            if "name" in item_name:
                item_name = item_name.get("name")
            elif "path" in item_name:
                item_name = item_name.get("path")
            else:
                item_name = u'JSON: "{0}"'.format(
                    stringtruncate(
                        json.dumps(item_name, separators=(",", ":")), width=36
                    )
                )
        task_host = self._get_host_string(result, "@")
        task_result = to_text("{0}{1} {2} ({3}) [{4}]").format(
            " " * (indent + 2), symbol_char, item_name, task_host, status.upper()
        )
        return task_result

    def _display_summary_table_separator(self, symbol_char):
        """Displays a line separating header or footer from content on the
        summary table.
        
        Args:
            symbol_char (:obj:`str`): The character to be used as the separator.
        """
        self.display(
            to_text(" {0} {1} {2} {3} {4} {5} {6}").format(
                symbol_char * 30,
                symbol_char * 7,
                symbol_char * 7,
                symbol_char * 7,
                symbol_char * 7,
                symbol_char * 7,
                symbol_char * 7,
            )
        )

    def _display_summary_table_row(
        self, host, success, changed, dark, failed, rescued, ignored
    ):
        """Displays a single line in the summary table, respecting the color and
        size given in the arguments.

        Each argument in this method is a tuple of three values:

        - The text;
        - The color;
        - The width;
        
        Args:
            host (:obj:`tuple` of :obj:`str`, :obj:`str`, int): Which host this
                row is representing.
            success (:obj:`tuple` of :obj:`str`, :obj:`str`, int): How many
                tasks were run successfully.
            changed (:obj:`tuple` of :obj:`str`, :obj:`str`, int): How many
                values were changed due to the execution of the task.
            dark (:obj:`tuple` of :obj:`str`, :obj:`str`, int): How many hosts
                were not reachable during the execution of this playbook.
            failed (:obj:`tuple` of :obj:`str`, :obj:`str`, int): How many tasks
                failed during their execution.
            rescued (:obj:`tuple` of :obj:`str`, :obj:`str`, int): How manu
                tasks where recover from a failure and were able to complete
                successfully.
            ignored (:obj:`tuple` of :obj:`str`, :obj:`str`, int): How many
                tasks were ignored.
        """
        self.display(
            to_text(" {0} {1} {2} {3} {4} {5} {6}").format(
                stringtruncate(host[0], host[1], host[2]),
                stringtruncate(success[0], success[1], success[2]),
                stringtruncate(changed[0], changed[1], changed[2]),
                stringtruncate(dark[0], dark[1], dark[2]),
                stringtruncate(failed[0], failed[1], failed[2]),
                stringtruncate(rescued[0], rescued[1], rescued[2]),
                stringtruncate(ignored[0], ignored[1], ignored[2]),
            )
        )

    def _display_task_decision_score(self, task):
        """Calculate the probability for the giving ``task`` to be displayed
        based on configurations and the task ``when`` clause.
        
        Args:
            task (:obj:`~ansible.playbook.task.Task`): The task object that
                will be analyzed.
        
        Returns:
            :obj:`Number`: A number between 0 and 1 representing the
            probability to show the giving ``task``. Currently this method
            only return 3 possible values:

            :0.0:
                When we are sure that the task should **not** be displayed.
                This means that we were able to process the ``when`` clause and
                it returned ``False``, or this ``task`` is a debug task and its
                verbosity does **not** cross the trashold for our playbook.
            :1.0:
                When we are sure the ``task`` should be displayed. This means
                that we were able to process the ``when`` clause and it returned
                ``True``, or this ``task`` is a debug task and its verbosity
                does cross the trashold for our playbook.
            :0.5:
                When we don't know if this task should be displayed or not. By
                default, we associate any ``task`` with this score, and change
                it if one of the conditions for the other scores are met.
        """
        score = 0.5
        var_manager = task.get_variable_manager()
        task_args = task.args
        if task.when and var_manager:
            all_hosts = CallbackModule.get_chainned_value(
                var_manager.get_vars(), "hostvars"
            )
            play_task_vars = var_manager.get_vars(
                play=self._current_play, host=self._current_host, task=task
            )
            templar = Templar(task._loader, variables=play_task_vars)
            exception = False
            for hostname in all_hosts.keys():
                host_vars = CallbackModule.get_chainned_value(all_hosts, hostname)
                host_vars.update(play_task_vars)
                try:
                    if not task.evaluate_conditional(templar, host_vars):
                        score = 0.0
                        break
                except Exception as e:
                    exception = True
            else:
                if not exception:
                    score = 1.0
        elif task.action == "debug" and task_args and "verbosity" in task_args:
            score = (
                1.0
                if self._is_run_verbose(verbosity=int(task_args["verbosity"]))
                else 0.0
            )
        return score

    def _display_task_name(self, task, is_handler=False):
        """Displays the giving ``task`` title.

        In reality, this method may or may not display the title based on some
        factors:

        If the :file:`ansible.cfg` has the ``display_skipped_hosts`` option set
        to ``True``, or if either of the environment variables
        (``ANSIBLE_DISPLAY_SKIPPED_HOSTS``, and ``DISPLAY_SKIPPED_HOSTS``) are
        set, the ``task`` title is displayed as soon as this method is called.

        Otherwise, this method will *cache* the ``task`` title until the
        :meth:`_flush_display_buffer` is called.
        
        Args:
            task (:obj:`~ansible.playbook.task.Task`): The task object that
                will be displayed in the console.
            is_handler (bool, optional): Flag indicating if this task is being
                handled by a different host. Defaults to False.

        See Also:
            - :meth:`_get_task_display_name`
            - :meth:`_display_task_decision_score`
            - :meth:`_flush_display_buffer`
        """
        self._item_processed = False
        self._get_task_display_name(task)

        if self.task_display_name:
            self._task_name_buffer = (
                self.task_display_name
                if not is_handler
                else "%s (via handler)..." % self.task_display_name
            )

            display_score = self._display_task_decision_score(task)
            if display_score >= 1.0 or C.DISPLAY_SKIPPED_HOSTS:
                self._flush_display_buffer()
            elif display_score < 0.1:
                self._task_name_buffer = None

    def _flush_display_buffer(self):
        """Display a task title if there is one to display.
        """
        if self._task_name_buffer:
            self.display(self._task_name_buffer)
            self._task_name_buffer = None

    @staticmethod
    def try_parse_string(text):
        """This method will try to parse the giving ``text`` using a JSON and
        a YAML parser in order to return a dictionary representing this parsed
        structure.
        
        Args:
            text (:obj:`str`): A text that may or may not be a JSON or YAML
                content.
        
        Returns:
            Returns the parser object from ``text``. If the giving ``text`` was
            not a JSON or YAML content, ``None`` will be returned.
        """
        textobj = None

        try:
            textobj = json.loads(text)
        except Exception as e:
            try:
                textobj = yaml.load(text, Loader=yaml.SafeLoader)
            except Exception:
                pass

        return textobj

    @staticmethod
    def dump_value(value):
        """Given a string, this method will parse the giving string and return
        the parsed object converted to a YAML representation.
        
        Args:
            value (:obj:`str`): A string to be parsed.
        
        Returns:
            :obj:`str`: The YAML representation of the object parsed from the
            giving ``value``.
        """
        text = None
        obj = CallbackModule.try_parse_string(value)
        if obj:
            text = yaml.dump(obj, Dumper=yaml.SafeDumper, default_flow_style=False)
        return text

    @staticmethod
    def reindent_session(title, text, indent=2, width=80):
        """This method returns a text formatted with the giving ``indent`` and
        wrapped at the giving ``width``.
        
        Args:
            title (:obj:`str`): The left most indented text.
            text (:obj:`str`): The rest of the text that will be indented two
                characters to the left of the ``title`` indentation.
            indent (int): Number of spaces used to indent the whole block.
                Defaults to 2.
            width (int, optional): How many characters are allowed to be used
                on a single line for this text block. Defaults to 80.
        
        Returns:
            :obj:`str`: The formatted text.
        """
        titleindent = " " * indent
        textindent = " " * (indent + 2)
        textwidth = width - (indent + len(title) + 2)
        textstr = str(text).strip()
        dumped = False
        if textstr.startswith("---") or textstr.startswith("{"):
            dumped = CallbackModule.dump_value(textstr)
            textstr = dumped if dumped else textstr
        output = to_text("\n{0}{1}:").format(titleindent, title)
        lines = textstr.splitlines()

        if (len(lines) == 1) and (len(textstr) <= textwidth) and (not dumped):
            output += " %s" % textstr
        else:
            for line in lines:
                output += "\n%s" % textwrap.fill(
                    text=line,
                    width=width,
                    initial_indent=textindent,
                    subsequent_indent=textindent,
                )
        return output

    @staticmethod
    def changed_artifacts(result, status, display_color):
        """Detect if the given ``result`` did change anything during its
        execution and return the proper status and display color for it.
        
        Args:
            result (:obj:`~ansible.executor.task_result.TaskResult`): The result
                object representing the execution of a task.
            status (:obj:`str`): A string representing the current status of
                the giving ``result``.
            display_color (:obj:`str`): A string representing the current status
                color of the giving ``result``.
        
        Returns:
            :obj:`tuple` of :obj:`str`, :obj:`str`: The return value depends on
            the giving ``result`` object. If this method detects the ``changed``
            flag in the ``result`` object, it returns::

                ("changed", "yellow")

            Otherwise, the values passed in the ``status`` and ``display_color``
            arguments will be used::

                (status, display_color)
        """
        result_was_changed = "changed" in result._result and result._result["changed"]
        if result_was_changed:
            return "changed", C.COLOR_CHANGED
        return status, display_color

    @staticmethod
    def get_chainned_value(mapping, *args):
        """Returns a value from a dictionary.

        It can return chainned values based on a list of keys giving by the
        ``args`` argument.

        Example:
            >>> crazy_dict = {
            ...     "a_key": "a_value",
            ...     "dict_key": {
            ...         "other_key": "other_value",
            ...         "other_dict_key": {
            ...             "target_value": "Found It!"
            ...         }
            ...     }
            ... }
            >>> CallbackModule.get_chainned_value(crazy_dict, "dict_key", "other_dict_key", "target_value")
            'Found It!'
        
        Args:
            mapping (:obj:`dict`): The dictionary used to fetch a value using
                chainned calls.
            *args: A list of keys to use to retrieve the deep value in the
                giving dictionary.
        
        Returns:
            Returns any value that matches the chain of keys passed in the
            ``args`` argument. If this value is a dictionary of some sort, the
            values of this dictionary will be shallowed copied to the returned
            dictionary.
        """
        if args:
            key = args[0]
            others = args[1:]

            if key in mapping:
                value = mapping[key]
                if others:
                    return CallbackModule.get_chainned_value(value, *others)
                if isinstance(value, Mapping):
                    dict_value = {}
                    dict_value.update(value)
                    return dict_value
                return value
        return None
