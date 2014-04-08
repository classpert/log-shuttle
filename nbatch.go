package main

import (
	"fmt"
	"io"
)

type NBatch struct {
	logLines []LogLine
}

func NewNBatch(capacity int) *NBatch {
	return &NBatch{logLines: make([]LogLine, 0, capacity)}
}

// Add a logline to the batch
func (nb *NBatch) Add(ll LogLine) {
	nb.logLines = append(nb.logLines, ll)
}

// The count of msgs in the batch
func (nb *NBatch) MsgCount() int {
	return len(nb.logLines)
}

type LogplexBatchFormatter struct {
	curLogLine   int // Current Log Line
	b            *NBatch
	curFormatter io.Reader // Current sub formatter
	config       *ShuttleConfig
}

func NewLogplexBatchFormatter(b *NBatch, config *ShuttleConfig) *LogplexBatchFormatter {
	return &LogplexBatchFormatter{b: b, config: config}
}

func (br *LogplexBatchFormatter) MsgCount() (msgCount int) {
	for _, line := range br.b.logLines {
		msgCount += 1 + int(len(line.line)/LOGPLEX_MAX_LENGTH)
	}
	return
}

func (br *LogplexBatchFormatter) Read(p []byte) (n int, err error) {
	// There is no currentReader, so figure one out
	if br.curFormatter == nil {
		currentLine := br.b.logLines[br.curLogLine]

		// The current line is too long, so make a sub batch
		if cll := currentLine.Length(); cll > LOGPLEX_MAX_LENGTH {
			subBatch := NewNBatch(int(cll/LOGPLEX_MAX_LENGTH) + 1)

			for i := 0; i < cll; i += LOGPLEX_MAX_LENGTH {
				target := i + LOGPLEX_MAX_LENGTH
				if target > cll {
					target = cll
				}

				subBatch.Add(LogLine{line: currentLine.line[i:target], when: currentLine.when})
			}

			// Wrap the sub batch in a reader
			br.curFormatter = NewLogplexBatchFormatter(subBatch, br.config)
		} else {
			br.curFormatter = NewLogplexLineFormatter(currentLine, br.config)
		}
	}

	n, err = br.curFormatter.Read(p)

	// if we're not at the last line and the err is io.EOF
	// then we're not done reading, so ditch the current reader
	// and move to the next log line
	if br.curLogLine < (br.b.MsgCount()-1) && err == io.EOF {
		err = nil
		br.curLogLine += 1
		br.curFormatter = nil
	}

	return
}

type LogplexLineFormatter struct {
	totalPos, headerPos, msgPos int // Positions in the the parts of the log lines
	headerLength, msgLength     int // Header and Message Lengths
	ll                          LogLine
	header                      string
}

func NewLogplexLineFormatter(ll LogLine, config *ShuttleConfig) *LogplexLineFormatter {
	syslogFrameHeader := fmt.Sprintf("<%s>%s %s %s %s %s %s ",
		config.Prival,
		config.Version,
		ll.when.UTC().Format(BATCH_TIME_FORMAT),
		config.Hostname,
		config.Appname,
		config.Procid,
		config.Msgid,
	)
	msgLength := len(ll.line)
	header := fmt.Sprintf("%d %s", len(syslogFrameHeader)+msgLength, syslogFrameHeader)
	return &LogplexLineFormatter{ll: ll, header: header, msgLength: msgLength, headerLength: len(header)}
}

func (llf *LogplexLineFormatter) Read(p []byte) (n int, err error) {
	if llf.totalPos >= llf.headerLength {
		n = copy(p, llf.ll.line[llf.msgPos:])
		llf.msgPos += n
		llf.totalPos += n
		if llf.msgPos >= llf.msgLength {
			err = io.EOF
		}
	} else {
		n = copy(p, llf.header[llf.headerPos:])
		llf.headerPos += n
		llf.totalPos += n
	}
	return
}