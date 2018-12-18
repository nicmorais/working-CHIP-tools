#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SCRIPT_NAME="$(basename $0)"
CHAT_SCRIPT="${SCRIPT_DIR}/${SCRIPT_NAME}.chat"
CHAT_BIN="$(which chat)"
CHAT_BIN="${CHAT_BIN:-/usr/sbin/chat}"


UART_DEVICE=ttyACM0
GETTY_UART_SERVICE="serial-getty@${UART_DEVICE}.service"
GETTY_DISABLED=0

export TIMEOUT=3

#echo "DUT_UART_RUN=$DUT_UART_RUN"

while getopts "t:" opt; do
	case $opt in
		t)
			TIMEOUT="${OPTARG}"
			echo "timeout set to ${TIMEOUT}"
			;;
		\?)
			echo "Invalid option: -$OPTARG" >&2
			exit 1
			;;
	esac
done
shift $((OPTIND-1))
export DUT_UART_PARAMETER="$@"


if [[ "$(systemctl is-active $GETTY_UART_SERVICE)" == "active" ]]; then
  echo "stopping $GETTY_UART_SERVICE"
  systemctl stop $GETTY_UART_SERVICE
  GETTY_DISABLED=1
fi

[[ -r "${CHAT_SCRIPT}" ]] || (echo "ERROR: can not read ${CHAT_SCRIPT}" && exit 1)
[[ -r "${CHAT_BIN}" ]] || (echo -e "ERROR: ${CHAT_BIN} not found\n -- 'sudo apt-get install ppp'" && exit 1)

for i in `seq 1 3`;
do
  echo -e "Waiting for serial gadget...Attempt(${i}/3)"
  /usr/sbin/chat -t $TIMEOUT -E -V -f "${CHAT_SCRIPT}" </dev/${UART_DEVICE} >/dev/${UART_DEVICE}\
  && break\
  || (echo -e "ERROR: failed to verify\n" && exit 1)
done
echo "SUCCESS: CHIP is powering down"

if [[ ${GETTY_DISABLED} == 1 ]]; then
  echo "starting $GETTY_UART_SERVICE"
  systemctl start $GETTY_UART_SERVICE
fi
