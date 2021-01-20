#!/usr/bin/env python
#
# FILE: keepAChangelog.py
#
# ABSTRACT: Tool to work with "Keep a Changelog" compatible CHANGELOG.md.
#
# AUTHOR: Ralf Schandl
#

"""
Tool to work with "Keep a Changelog" compatible CHANGELOG.md.
See https://keepachangelog.com

Usage: keepAChangelog.py [OPTIONS] <COMMAND> [COMMAND_PARAMETER...]

OPTIONS:
    -f, --file FILE  Use given file as CHANGELOG.md instead as file from
                     current directory.
    -n, --no-scm     Don't call SCM to check version tags.
    -i, --ignore     Continue even when CHANGELOG.md is detected as invalid
                     during loading. Some problem can't be ignored, e.g. a
                     invalid formatted version.
    -B, --no-file-backup
                     Don't create a backup file when writing CHANGELOG.md
    -q, --quiet      Be quiet. Use "-q" to suppress info output, "-qq" to
                     suppress info and warning and "-qqq" to also supress
                     error messages.
    -d, --debug      Enable debug output. Use multiple times to see more
                     details.

COMMAND:
    validate         Validates CHANGELOG.md. Only validates some basic
                     rules, like:
                     - valid version names
                     - not more than one unreleased version
                     Does NOT validate markdown!

    print            Prints CHANGELOG.md to stdout. Reformatted!

    ready            Checks if the change log is ready for release. Every
                     version entry needs a release date, the links to Github
                     compare must contain versions tags. Every version needs
                     a corresponding SCM tag (except "-n" is given).

    release VERSION  Updates CHANGELOG.md to release the given version. Will
                     always print a warning that a SCM tag should be created.

    info VERSION     Prints the change log entry for the given version. The
                     header line is not printed, just the body.

    rewrite          Rewrites CHANGELOG.md reformatted.

Notes:
    reformatting:
        Whenever the tools writes out the CHANGELOG.md (either to file or to
        screen), some basic reformatting happens:
            - blank lines might be added or removed
            - Whitespaces within markdown h1 or h2 header and links might be
              normalized.
            - Links at the end of the document might be reordered.
        There is NO reformating regarding line length, indent etc!

    unreleased:
        The tool accepts two types of formatting for unreleased change entries.
        Either (as prefered by keepachangelog.com):
            ## [Unreleased]
        Or (as prefered by me :-)):
            ## [0.2.0] - UNRELEASED

    SCM:
        Currently only GIT with GitHub is supported.

"""

from __future__ import print_function

import os
import sys
import errno
import re
import subprocess
import getopt
from datetime import datetime
from collections import namedtuple
from enum import Enum

# Name of this program. If changed also change doc string.
PROGRAM = "keepAChangelog.py"

# Version of this tool. Sure we use SemVer ;-)
VERSION = "0.1.0"

DEVNULL = open(os.devnull, "wb")

#---------[ RegEx ]------------------------------------------------------------
# Regualar expressions used to parse the CHANGELOG.md

# Matches a SemVer compatible version
#
# Pattern to match a semver.org compatible version number.
# E.g: 1.0.0, 0.1.0-rc.3, 1.0.0-rc.4+20180508144700
#
VERSION_PATTERN = r"""
    ^
    (?P<major>(?:0|[1-9][0-9]*))
    (
    \.
    (?P<minor>(?:0|[1-9][0-9]*))
    (
    \.
    (?P<patch>(?:0|[1-9][0-9]*))
    )?
    )?
    (-(?P<prerelease>
        (?:(?:0|[1-9][0-9]*)|(?:[0-9A-Za-z][-0-9A-Za-z]*))
        (?:\.(?:(?:0|[1-9][0-9]*)|(?:[0-9A-Za-z][-0-9A-Za-z]*)))*
    ))?
    (\+(?P<meta>
        [0-9A-Za-z-]+
        (\.[0-9A-Za-z-]+)*
    ))?
    $
    """

# Pattern to match a H1 line start and entire line
H1_PATTERN = r"^#[^#].*$"
TITLE_PATTERN = r"^# *(?P<title>[^#].*)$"

# Pattern to match a H2 line start and entire version header
H2_PATTERN = r"^##[^#].*$"
VERS_HDR_PATTERN = r"^##  *(\[)?(?P<version>[^\s\]]*)(\])?(  *-  *(?P<date>\d{4}-\d{2}-\d{2})? *(?P<note>[^ ].*[^ ])?)?$"

# Matches an empty line (ignores whitespaces)
EMPTY_LINE_PATTERN = r"^\s*$"


# matches the start of a link and a entire link line
LINK_START_PATTERN = r"^\[\w[^\s\]]*\]:.*$"
LINK_PATTERN = r"^\[(?P<label>\w[^\s\]]*)\]:  *(?P<href>[^ ]*)$"

# Matches a comment
COMMENT_PATTERN = r"^\[//\]:.*$"

# Compiled RegExes for pattern
VERSION_RE = re.compile(VERSION_PATTERN, re.VERBOSE)
TITLE_RE = re.compile(TITLE_PATTERN)
VERS_HDR_RE = re.compile(VERS_HDR_PATTERN)
EMPTY_LINE_RE = re.compile(EMPTY_LINE_PATTERN)
H1_RE = re.compile(H1_PATTERN)
H2_RE = re.compile(H2_PATTERN)
LINK_RE = re.compile(LINK_PATTERN)
LINK_START_RE = re.compile(LINK_START_PATTERN)
COMMENT_RE = re.compile(COMMENT_PATTERN)

#---------[ Exceptions ]-------------------------------------------------------
class KaclException(Exception):
    """
    Base exception. Exceptions of this type are catched in main() and the
    message is printed.
    """
    pass

class CmdException(KaclException):
    """
    Somthing failed during command execution. E.g. Missing parameter.
    """
    pass

class ValidateException(KaclException):
    """
    Exception thrown whenever something is seriously wrong with the CHANGELOG.md.
    Message should contain the file name and affected line.
    """
    def __init__(self, location, message):
        super(ValidateException, self).__init__("%s %s" % (location.location(), message))

# Thrown when parsing a version string fails
class InvalidVersionException(KaclException):
    """
    Exception thrown if a invalid version was found.
    """
    def __init__(self, version_string):
        super(InvalidVersionException, self).__init__("Invalid version: \"%s\"" % version_string)

#---------[ Classes ]----------------------------------------------------------
class Scm(Enum):
    """ Enum for SCM systems. """
    git = 1

class Version(object):
    """
    Represents version number in a CHANGELOG.md. This is either
    a semver.org compatible version number or the String "Unreleased".
    "Unreleased" is the highest possible version number.
    """
    def __init__(self, version_str):
        if version_str.lower() == "unreleased":
            self.version = "Unreleased"
            self.major = -1
            self.minor = -1
            self.patch = -1
            self.prerelease = None
            self.meta = None
        else:
            match = VERSION_RE.match(version_str)
            if match is None:
                raise InvalidVersionException(version_str)
            else:
                self.version = version_str
                self.major = int(match.group("major"))
                self.numeric = "%d" % (self.major)
                if  match.group("minor") is not None:
                    self.minor = int(match.group("minor"))
                    self.numeric = "%s.%d" % (self.numeric, self.major)
                    if  match.group("patch") is not None:
                        self.patch = int(match.group("patch"))
                        self.numeric = "%s.%d" % (self.numeric, self.patch)
                    else:
                        self.patch = 0
                else:
                    self.minor = 0
                    self.patch = 0

                if (self.major + self.minor + self.patch) == 0:
                    raise InvalidVersionException(version_str)
                self.prerelease = match.group("prerelease")
                self.meta = match.group("meta")

        #self.numeric = "%d.%d.%d" % (self.major, self.minor, self.patch)

    def __hash__(self):
        return hash(self.version)

    def __eq__(self, other):
        if not isinstance(self, other.__class__):
            return False
        return self.__dict__ == other.__dict__

    def __ne__(self, other):
        return not self.__eq__(other)

    def __lt__(self, other):
        if not isinstance(other, Version):
            return NotImplemented
        return self._compare(other) < 0

    def __le__(self, other):
        if not isinstance(other, Version):
            return NotImplemented
        return self._compare(other) <= 0

    def __ge__(self, other):
        if not isinstance(other, Version):
            return NotImplemented
        return self._compare(other) >= 0

    def __gt__(self, other):
        if not isinstance(other, Version):
            return NotImplemented
        return self._compare(other) > 0

    def _compare(self, other):
        result = 0
        # handle "Unreleased"
        if self.version == -1 or other.version == -1:
            return cmp(other.major, self.major)

        if cmp(self.major, other.major):
            result = cmp(self.major, other.major)
        elif cmp(self.minor, other.minor):
            result = cmp(self.minor, other.minor)
        elif cmp(self.patch, other.patch):
            result = cmp(self.patch, other.patch)
        elif self.prerelease is None and other.prerelease is None:
            result = 0
        elif self.prerelease is None:
            result = 1
        elif other.prerelease is None:
            result = -1
        else:
            result = Version._cmp_prerelease(self.prerelease, other.prerelease)
        return result

    @staticmethod
    def _cmp_prerelease(pr1_str, pr2_str):
        pr1 = Version._split_prerelease(pr1_str)
        pr2 = Version._split_prerelease(pr2_str)
        for part1, part2 in zip(pr1, pr2):
            result = 0
            if isinstance(part1, int) and isinstance(part2, int):
                result = cmp(part1, part2)
            elif isinstance(part1, int):
                result = -1
            elif isinstance(part2, int):
                result = 1
            else:
                result = cmp(part1, part2)
            if result != 0:
                return result
        # all parts so far equal, compare list length
        return cmp(len(pr1), len(pr2))

    @staticmethod
    def _split_prerelease(pr_str):
        return [(int(part) if part.isdigit() else part) for part in pr_str.split(".")]

    def __str__(self):
        return self.version

class FileLocation(object):
    """
    Base Class for something that knows its location in a file (name & linenumber).
    """
    def __init__(self, filename, line_num):
        self.filename = filename
        self.line_num = line_num

    def location(self):
        """ Returns location string "filename[line-number]" """
        return "%s[%d]" % (self.filename, self.line_num)

    def __str__(self):
        self.location()

class Section(FileLocation):
    """
    Base class for a section with title and body.
    Title is to be handled in derived classes.
    """
    def __init__(self, filename, line_num):
        super(Section, self).__init__(filename, line_num)
        self.content = []
        self.last_empty = False

    def add_line(self, line_num, line):
        """
        Add a line to the body of the section.
        Note: Ignores empty lines if previous line was also empty.
        """
        # pylint: disable=unused-argument
        # only add empty line if previous line is not empty.
        if line == "":
            if (not self.content) or self.content[-1] != "":
                self.content.append(line)
        else:
            self.content.append(line)

    def finish(self):
        """ Finish up the body. E.g. delete trailing empty line. """
        # remove trailing empty line
        if self.content and self.content[-1] == "":
            self.content = self.content[:-1]

    def body(self):
        """ returns the body of the section. """
        txt = ""
        for line in self.content:
            txt = txt + "%s\n" % line
        return txt.strip()

    def title(self):
        """ returns the markdown formatted title. Must be implemented by derived classes. """
        raise NotImplementedError(self.__class__.__name__ + " needs to override method title")

    def section(self, title):
        """ Returns the entire section with title and body (if any). """
        body = self.body()
        if body:
            return title + "\n\n" + body
        else:
            return title

    def  __str__(self):
        body = self.body()
        if body:
            return self.title() + "\n\n" + body
        else:
            return self.title()

#
#
class Title(Section):
    """
    Title section with title line and body
    """
    def __init__(self, filename, line_num, line):
        super(Title, self).__init__(filename, line_num)
        match = TITLE_RE.match(line)
        if match is None:
            raise ValidateException(self, "Invalid title: %s" % line)
        else:
            self.title_str = match.group("title")

    def title(self):
        return "# " + self.title_str


class VersionEntry(Section):
    """
    Version section with title line and body
    """
    def __init__(self, filename, line_num, line):
        super(VersionEntry, self).__init__(filename, line_num)
        match = VERS_HDR_RE.match(line)
        if match is None:
            raise ValidateException(self, "Invalid version header: %s" % line)
        else:
            try:
                self.version = Version(match.group("version"))
            except InvalidVersionException as exc:
                raise ValidateException(self, "%s" % str(exc))

            self.date = match.group("date")
            self.note = match.group("note")
        self.compare_link = None

    def title(self):
        txt = ""
        if self.compare_link:
            txt = "## [%s]" % self.version
        else:
            txt = "## %s" % self.version
        if self.date or self.note:
            txt = txt + " -"
        if self.date != None:
            txt = txt + " %s" % self.date
        if self.note != None:
            txt = txt + " %s" % self.note
        return txt


class Link(FileLocation):
    """
    A link. "[label]: http://..."
    """
    def __init__(self, filename, line_num, line):
        super(Link, self).__init__(filename, line_num)
        match = LINK_RE.match(line)
        if match is None:
            raise ValidateException(self, "Invalid link: %s" % line)
        else:
            self.label = match.group("label")
            self.href = match.group("href")
            debug("Link Label: >>%s<<" % self.label)
            try:
                self.version = Version(self.label)
                v_str = self.version.version
                self.bounded = self.href.endswith("...v%s" % v_str)
            except InvalidVersionException:
                if re.match(r"^\d\.", self.label) and not CONFIG.ignore_invalid:
                    warning("%s Link label looks like a version, but is not: %s" % (self.location(), self.label))
                self.version = None

    def __str__(self):
        return "[%s]: %s" % (self.label, self.href)

#
#
class Comment(FileLocation):
    """
    A comment: "[//]: ..."
    """
    def __init__(self, filename, line_num, line):
        super(Comment, self).__init__(filename, line_num)
        match = COMMENT_RE.match(line)
        if match is None:
            raise ValidateException(self, "Invalid comment: %s" % line)
        else:
            self.text = line

    def __str__(self):
        return self.text

#
#
class ChangeLog(object):
    """
    The complete changelog file
    """
    # pylint: disable=too-many-instance-attributes
    # Nine is reasonable in this case
    def __init__(self, filename):
        self.filename = filename
        # init members
        self.version_dict = {}
        self.version_list = []
        self.entry_list = []
        self.last_version = None
        self.first_version = None
        self.file_comment = None
        # Load the file
        self.__load()
        # validate, but do not complain
        self.silent = True
        self.valid = self.validate()
        self.silent = False

    def __load(self):
        # pylint: disable=too-many-branches
        # Parsing Markdown requires that
        debug2("Loading %s" % self.filename)
        with open(self.filename, "r") as inputfile:
            sec = None
            line_num = 0
            for line in inputfile:
                if self.file_comment:
                    if isinstance(sec, Section):
                        sec.add_line(line_num, self.file_comment.__str__())
                        self.file_comment = None
                    else:
                        raise ValidateException(self.__file_loc(line_num), "Stray comment - don't know how to handle")

                line_num += 1
                line = line.rstrip()
                debug2("Read >>%s<<" % line)
                if not self.entry_list and EMPTY_LINE_RE.match(line):
                    continue
                if H1_RE.match(line):
                    debug2("    Hit H1")
                    self.__finish_entry(sec)
                    sec = Title(self.filename, line_num, line)
                    self.entry_list.append(sec)
                elif H2_RE.match(line):
                    debug2("    Hit H2")
                    self.__finish_entry(sec)
                    sec = VersionEntry(self.filename, line_num, line)
                    if self.last_version is None:
                        self.last_version = sec.version
                    self.first_version = sec.version
                    self.entry_list.append(sec)
                elif LINK_START_RE.match(line):
                    debug2("    Hit LINK")
                    if isinstance(sec, Section):
                        self.__finish_entry(sec)
                    link = Link(self.filename, line_num, line)
                    if link.version:
                        self.__add_version_compare_link(link)
                    else:
                        self.entry_list.append(link)
                    sec = None
                else:
                    if COMMENT_RE.match(line):
                        debug2("    Hit COMMENT")
                        self.file_comment = Comment(self.filename, line_num, line)
                    elif isinstance(sec, Section):
                        debug2("    Append to section %s" % sec.title())
                        sec.add_line(line_num, line)
                    else:
                        if line != "":
                            raise ValidateException(self.__file_loc(line_num), "%s does not support body: %s" %
                                    (sec.__class__.__name__, line))

        if isinstance(sec, Section):
            self.__finish_entry(sec)
        debug2("Finished loading %s" % self.filename)


    #
    # Add a version compare link to the appropriate version
    #
    def __add_version_compare_link(self, link):
        if link.version in self.version_dict:
            v_entry = self.version_dict[link.version]
            if v_entry.compare_link is None:
                v_entry.compare_link = link
            else:
                raise ValidateException(link, "Duplicate link: %s" %
                        link.version)

            if v_entry.date and not link.bounded:
                raise ValidateException(link, "Unbounded link: %s" %
                        link.href)

        else:
            raise ValidateException(link, "Link for unknown version: %s" %
                    link.__str__())

    def __finish_entry(self, entry):
        if entry is None:
            return
        entry.finish()
        if isinstance(entry, VersionEntry):
            vers = entry.version
            if vers in self.version_dict:
                raise ValidateException(self.version_dict[vers], "Duplicate version  \"%s\". See also line %d" %
                        (vers, entry.line_num))
            self.version_dict[vers] = entry
            self.version_list.append(vers)

    def validate(self, allow_missing_tag_for_version=None):
        """
        Validate the changelog

        Optional: allow_missing_tag_for_version The given version does not need
        a SCM tag
        """
        file_dir = os.path.dirname(os.path.abspath(self.filename))
        valid = True
        if not self.version_list:
            self.__file_error(0, "No version information found in file")
            valid = False

        for key in self.version_list:
            v_entry = self.version_dict[key]
            if v_entry.date is None and key != self.last_version:
                self.__file_error(v_entry.line_num, "Unexpected unreleased version: %s" % key)
                valid = False
            if v_entry.compare_link is None and key != self.first_version:
                self.__file_error(v_entry.line_num, "Version without compare link: %s" % key)
                valid = False
            if CONFIG.scm and v_entry.date:
                scm_date = get_scm_tag_date(key.version, file_dir)
                if scm_date:
                    if v_entry.date != scm_date:
                        self.__file_error(v_entry.line_num,
                                "Version %s release date and SCM tag date differ: \"%s\" <-> \"%s\"" %
                                (key.version, v_entry.date, scm_date))
                        valid = False
                elif key.version != allow_missing_tag_for_version:
                    self.__file_error(v_entry.line_num, "No SCM tag for version %s (searched for tag \"v%s\")" %
                            (key.version, key.version))
                    valid = False

        return valid

    def version_body(self, version_str):
        """
        Return the version change info for the given version
        """
        version = Version(version_str)
        if version in self.version_dict:
            return self.version_dict[version].body()
        else:
            return None

    def release(self, version_str):
        """
        Release a version. Version number is given as parameter.
        """
        version = Version(version_str)
        unr = None
        unreleased_found = False
        if version in self.version_dict:
            unr = self.version_dict[version]
        if unr is None:
            unreleased = Version("Unreleased")
            if unreleased in self.version_dict:
                unr = self.version_dict[unreleased]
                unreleased_found = True
        if unr is None:
            raise CmdException("Neither entry \"%s\" nor \"Unreleased\" found" % version)

        today = datetime.now().strftime("%Y-%m-%d")
        info("Releasing %s -> %s(%s)" % (unr.version.version, version.version, today))
        unr.version = version
        unr.date = today
        unr.note = None
        new_link = re.sub(r"...[^.\s]+$", "...v%s" % version.version, unr.compare_link.href)
        if new_link != unr.compare_link.href:
            unr.compare_link.href = new_link
            unr.compare_link.bounded = True
        else:
            raise CmdException("%s Failed to created bounded link for version %s from: %s" %
                    (unr.compare_link.location(), version.version, unr.compare_link.href))

        if unreleased_found:
            # We moved version "Unreleased" to version "x.y.z": Need to update tables
            self.version_list = [version if x == unreleased else x for x in self.version_list]
            self.version_dict[version] = self.version_dict[unreleased]
            del self.version_dict[unreleased]
            if self.last_version == unreleased:
                self.last_version = version
            if self.first_version == unreleased:
                self.first_version = version


    def is_releasable(self, allow_missing_tag_for_version=None):
        """
        Checks if the change log is releasable. No unreleased versions
        and no compare links that don't end with a version are allowed.

        Optional: allow_missing_tag_for_version The given version does not need
        a SCM tag
        """
        valid = self.validate(allow_missing_tag_for_version)
        check = True
        for entry in self.version_list:
            v_entry = self.version_dict[entry]
            if v_entry.date is None:
                self.__file_error(v_entry.line_num, "Version without release date: %s" % entry)
                check = False

            if re.search(r"SNAPSHOT", entry.version, re.IGNORECASE):
                self.__file_error(v_entry.line_num, "Version containing \"SNAPSHOT\": %s" % entry)
                check = False

            if v_entry.compare_link and not v_entry.compare_link.bounded:
                self.__file_error(v_entry.compare_link.line_num, "Unbounded compare link for version %s: %s" %
                        (entry, v_entry.compare_link.href))
                check = False

        return valid and check

    # Print the change log to the given stream
    def __do_print(self, stream):
        print("", file=stream)
        for entry in self.entry_list:
            print(entry, file=stream)
            if not isinstance(entry, Link):
                print("\n", file=stream)

        print("", file=stream)
        if self.__print_compare_links(stream):
            print("", file=stream)
        if self.file_comment:
            print(self.file_comment, file=stream)

    #
    # Print the compare links (called by __do_print(...))
    # returns True if at least one line was printed
    #
    def __print_compare_links(self, stream):
        printed = False
        for entry in self.version_list:
            v_entry = self.version_dict[entry]
            if v_entry.compare_link:
                print("[%s]: %s" % (v_entry.version.version, v_entry.compare_link.href), file=stream)
                printed = True
        return printed

    def print(self):
        """ Print the changelog to stdout. """
        self.__do_print(sys.stdout)

    def write(self):
        """
        Write the changelog back to the file it was read from.
        Creates a backup file with extesion ".kaclBackup".
        """
        self.__create_backup()
        with open(self.filename, "w") as outputfile:
            self.__do_print(outputfile)

    def __create_backup(self):
        if CONFIG.filebackup:
            backup_file = self.filename + ".kaclBackup"
            try:
                os.remove(backup_file)
            except OSError as exc:
                if exc.errno == errno.ENOENT:
                    pass
                else:
                    raise

            os.rename(self.filename, backup_file)

    def __file_error(self, line_num, message):
        if not self.silent:
            loc = self.__file_loc(line_num)
            print_stderr("%s ERROR: %s" % (loc.location(), message))

    def __file_loc(self, line_num):
        return FileLocation(self.filename, line_num)

#---------[ COMMANDS ]---------------------------------------------------------


def cmd_validate(cmd, argv):
    """ Validates CHANGELOG.md """
    assert_no_args(cmd, argv)
    if ChangeLog(CONFIG.changelog).validate():
        info("VALID")
        return 0
    else:
        return 1

def cmd_print(cmd, argv):
    """ Prints CHANGELOG.md """
    assert_no_args(cmd, argv)
    load_validated().print()
    return 0

def cmd_ready(cmd, argv):
    """ Checks if CHANGELOG.md is ready for release. """
    assert_no_args(cmd, argv)
    if load_validated().is_releasable():
        info("YES")
        return 0
    else:
        info("NO")
        return 1

def cmd_release(cmd, argv):
    """
    Adds release date to unreleased version and fixes the compare link.
    Requires the version as parameter
    """
    assert_arg_count(cmd, argv, 1)
    version = argv.pop(0)
    clg = load_validated()
    clg.release(version)
    if clg.is_releasable(version):
        clg.write()
        info("DON'T FORGET to create a release tag %s" % version)
        return 0
    else:
        error("Not written")
        return 1

def cmd_info(cmd, argv):
    """
    Prints the section body of the given version.
    """
    assert_arg_count(cmd, argv, 1)
    version = argv.pop(0)
    txt = load_validated().version_body(version)
    if txt:
        print(txt)
        return 0
    else:
        error("No info for version %s available" % version)
        return 1

def cmd_rewrite(cmd, argv):
    """
    Writes the CHANGELOG.md. This might result in reformatting.
    """
    assert_no_args(cmd, argv)
    load_validated().write()
    return 0

def cmd_versions(cmd, argv):
    """
    List the versions and release dates.
    """
    assert_no_args(cmd, argv)
    clg = load_validated()
    for vers in clg.version_list:
        rel_date = clg.version_dict[vers].date if clg.version_dict[vers].date else "Unreleased"
        print("%10s: %s" % (rel_date, vers))
    return 0

# Commands supporting functions

def load_validated():
    """
    Loads the configured changelog file and throws a ValidateException if the
    file is detected as invalid.
    """
    clg = ChangeLog(CONFIG.changelog)
    if (not clg.valid) and (not CONFIG.ignore_invalid):
        raise CmdException("%s: File is invalid - check with \"validate\" or use \"-i\"" % CONFIG.changelog)
    return clg

def assert_no_args(cmd, argv):
    """ Asserts that argv is empty. """
    if len(argv) != 0:
        raise CmdException("Command \"%s\" does not support arguments." % cmd)

def assert_arg_count(cmd, argv, count):
    """ Asserts that argv contains the given number of elements. """
    if len(argv) != count:
        raise CmdException("Invalid number of arguments for command \"%s\": Expected %d, got %d"
                % (cmd, count, len(argv)))

#---------[ Functions ]--------------------------------------------------------

def error(message):
    """ Print a error message with prefix "ERROR:" to stderr. """
    # there might be error messages before CONFIG is created
    if (not CONFIG) or CONFIG.quiet < 3:
        print_stderr("ERROR: %s" % message)

def warning(message):
    """ Print a warning message with prefix "WARNING:" to stderr. """
    if CONFIG.quiet < 2:
        print_stderr("WARNING: %s" % message)

def info(message):
    """ Print a info message to stdout. """
    if CONFIG.quiet < 1:
        print("%s" % message)

def debug(message):
    """ If debug level is greater 0, print a debug message with prefix "DEBUG:" to stderr. """
    if CONFIG.debug > 0:
        print_stderr("DEBUG: %s" % message)

def debug2(message):
    """ If debug level is greater 1, print a debug message with prefix "DEBUG:" to stderr. """
    if CONFIG.debug > 1:
        print_stderr("DEBUG: %s" % message)

def print_stderr(message):
    """ Prints to stderr. """
    print(message, file=sys.stderr)

def run_cmd(os_cmd, cwd):
    """ Run command and return stdout """
    prc = subprocess.Popen(os_cmd, stdout=subprocess.PIPE, stderr=DEVNULL, shell=True, cwd=cwd)
    output = prc.communicate()[0]
    out = output.decode(sys.stdout.encoding).__str__().rstrip()
    debug("%s: Exit-Code: %d Output: >>%s<<" % (os_cmd, prc.returncode, out))
    return out

def get_scm_tag_date(version, working_dir):
    """ Returns the date of the tagged version. """
    tag_date = None
    if CONFIG.scm == Scm.git:
        tag_date = run_cmd("git log -1 --date=short --format=%%ad \"v%s\"" %
                version, working_dir)
    return tag_date

def is_in_git_working_tree(filename):
    """ Is the given filename located within a GIT working tree? """
    file_dir = os.path.dirname(os.path.abspath(filename))
    out = run_cmd("git rev-parse --is-inside-work-tree", file_dir)
    return out.strip() == "true"

#---------[ MAIN ]-------------------------------------------------------------

# scm: (Enum) Scm (e.g.git) to get tags and tag-dates. Default: git if in git working dir
# changelog: (String) Name of the change log file to use. Default: CHANGELOG.md
# ignore_invalid: (Bool) Ignore if file was detected as invalid. Default: False
# filebackup: (Bool) Whether to create a backuo before writing the file. Default: True
# quiet: (int) Quiet level.
# debug: (Bool) Print debug output.
#
Config = namedtuple("Config", "scm changelog ignore_invalid filebackup quiet debug")
CONFIG = Config(scm=None, changelog="CHANGELOG.md", ignore_invalid=False,
            filebackup=True, quiet=0, debug=0)

def handle_options(sys_argv):
    """
    Handle command line options and create global CONFIG named tuple.
    Returns command list with command and command parameters.
    Raises a SystemExit(1) on error and SystemExit(0) after processing
    --version or --help.
    """
    # pylint: disable=global-statement
    # CONFIG is the global configuration namedtuple
    global CONFIG

    use_scm = True
    chglog_file = None
    ignore_invalid = False
    filebackup = True
    # quiet level: 0: print all, 1: warnings + error, 2: only errors
    quiet = 0
    debug_level = 0

    # parameter handling
    try:
        opt_tuple_list, argv = getopt.getopt(sys_argv, "f:niBqd",
                ["help", "version", "file=", "no-scm", "ignore", "no-file-backup", "quit", "debug"])
        for opt_tuple in opt_tuple_list:
            opt = opt_tuple[0]
            value = opt_tuple[1]
            if opt in ("--no-scm", "-n"):
                use_scm = False
            elif opt in ("--file", "-f"):
                if chglog_file:
                    error("Duplicate option -f")
                    raise SystemExit(1)
                chglog_file = value
            elif opt in ("--ignore-invalid", "-i"):
                ignore_invalid = True
            elif opt in ("--no-file-backup", "-B"):
                filebackup = False
            elif opt in ("--quiet", "-q"):
                quiet += 1
            elif opt in ("--debug", "-d"):
                debug_level += 1
            elif opt == "--help":
                print(__doc__)
                raise SystemExit(0)
            elif opt == "--version":
                print("%s V %s" % (PROGRAM, VERSION))
                raise SystemExit(0)
            else:
                error("Can't handle option \"%s\" -- implementation error" % opt)
                raise SystemExit(1)
    except getopt.GetoptError as exc:
        error(str(exc))
        raise SystemExit(1)

    CONFIG = Config(scm=None, changelog=chglog_file, ignore_invalid=ignore_invalid,
            filebackup=filebackup, quiet=quiet, debug=debug_level)

    if chglog_file is None:
        chglog_file = "CHANGELOG.md"

    if not use_scm:
        scm = None
    elif is_in_git_working_tree(chglog_file):
        debug("In git working copy -- enabling scm git")
        scm = Scm.git
    else:
        scm = None

    CONFIG = Config(scm=scm, changelog=chglog_file, ignore_invalid=ignore_invalid,
            filebackup=filebackup, quiet=quiet, debug=debug_level)


    debug("Config: %s" % str(CONFIG))

    return argv


def main():
    """ Main function. """
    argv = handle_options(sys.argv[1:])

    if len(argv) < 1:
        error("Missing command")
        print(__doc__)
        return 1

    cmd = argv.pop(0) # pylint: disable=no-member

    exit_code = 1
    try:
        cmd_func = "cmd_%s" % cmd
        if cmd_func in globals():
            exit_code = globals()[cmd_func](cmd, argv)
        else:
            error("Unknown command: %s" %cmd)
            print(__doc__)
    except KaclException as exc:
        error(str(exc))
    except IOError as exc:
        error(str(exc))

    return exit_code

# call main()
sys.exit(main())

