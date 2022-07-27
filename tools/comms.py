import struct
import serial
import sys

BEGIN_PACKET_BYTE = 0x55
END_PACKET_BYTE = 0xAA

STATE_SEARCH_FOR_START  = 0
STATE_READ_PACKET       = 1

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Need to specify serial port name/path.")
        exit()
    
    ser = serial.Serial(sys.argv[1])
    ser.baudrate = 115200
    ser.timeout = 1.0
    
    ind = 0
    SIZE = 64
    arr = bytearray(SIZE)
    state = STATE_SEARCH_FOR_START
    end_pack_counter = 0
    printstr = ""
    while ser.is_open:
        try:
            x = ser.read(1)
            if len(x) > 0:
                arr[ind] = x[0]
            else:
                print("Received nothing...")
            
            if state == STATE_SEARCH_FOR_START:
                if arr[ind] == BEGIN_PACKET_BYTE and (ind == 0 or arr[ind-1] == BEGIN_PACKET_BYTE):
                    ind += 1
                else:
                    ind = 0
                
                if ind == 4:
                    # found 4 consecutive BEGIN_PACKET_BYTEs
                    ind = 0
                    state = STATE_READ_PACKET
            elif state == STATE_READ_PACKET:
                
                
                printstr += "0x{:x}\t".format(arr[ind]) # print the byte we just read

                if arr[ind] == END_PACKET_BYTE:
                    if end_pack_counter == 0:
                        end_pack_counter += 1
                    elif arr[ind-1] == END_PACKET_BYTE:
                        end_pack_counter += 1
                    else:
                        end_pack_counter = 0
                
                # increment ind, wrap around if we've reached size
                ind += 1
                if ind >= SIZE:
                    ind = 0

                # check if we've reached the end
                if end_pack_counter == 4:
                    data = struct.unpack_from("<BBBiii", arr, 0)
                    waveform        = data[0]
                    gain_setting    = data[1]
                    offset          = data[2]
                    amp_enc_counts  = data[3]
                    freq_enc_counts = data[4]
                    clk_div         = data[5]
                    # print(printstr, end="\r\n")
                    print("WAVE={:<4d}| GAIN={:<4d}| OFFSET={:<4d}| AMP_ENC={:<6d}| FREQ_ENC={:<6d}| CLK_DIV={:<6d}".format(waveform, gain_setting, offset, amp_enc_counts, freq_enc_counts, clk_div))
                    printstr = ""
                    end_pack_counter = 0
                    ind = 0
                    state = STATE_SEARCH_FOR_START

                
        except serial.SerialTimeoutException:
            print("Timed out.")
        except KeyboardInterrupt:
            print("Exiting...")
            exit()
