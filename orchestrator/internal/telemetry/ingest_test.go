package telemetry

import (
	"encoding/binary"
	"testing"
)

func TestDecodeSnapshot(t *testing.T) {
	buf := make([]byte, 8+4+4+1+2+2+4+4)
	binary.LittleEndian.PutUint64(buf[0:], 133_000_000_000_000_000)
	binary.LittleEndian.PutUint32(buf[8:], 0)
	binary.LittleEndian.PutUint32(buf[12:], 4)
	buf[16] = 6
	binary.LittleEndian.PutUint16(buf[17:], 51732)
	binary.LittleEndian.PutUint16(buf[19:], 443)
	binary.LittleEndian.PutUint32(buf[21:], 1)
	binary.LittleEndian.PutUint32(buf[25:], 0)

	e, err := DecodeSnapshot(buf)
	if err != nil {
		t.Fatal(err)
	}
	if e.Protocol != ProtocolTCP || e.LocalPort != 51732 || e.RemotePort != 443 {
		t.Fatalf("unexpected decoded event: %+v", e)
	}
}

func TestDecodeSnapshotRejectsShortBuffer(t *testing.T) {
	if _, err := DecodeSnapshot(make([]byte, 3)); err == nil {
		t.Fatal("expected short-buffer error")
	}
}
