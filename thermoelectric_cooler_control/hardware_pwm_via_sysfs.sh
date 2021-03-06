#!/usr/bin/bash


main()
{
  arg_parse "$@"

  if [ ! -d "/sys/class/pwm/pwmchip0/pwm$CHANNEL" ]
  then
    export_channel
  fi

  printf "Hardware PWM:\t"
  printf CHANNEL=$CHANNEL"\t"
  printf OPERATION=$OPERATION"\t"

  PERIOD=$((1000000000 / $FREQUENCY)) #in nanoseconds
  DUTY_CYCLE_NANOSEC=$((PERIOD * DUTY_CYCLE / 100))
#  PREVIOUS_DUTY_CYCLE=`cat /sys/class/pwm/pwmchip0/pwm0/duty_cycle`
#
#  if [[ $PERIOD < $PREVIOUS_DUTY_CYCLE ]]
#  then
#    echo PERIOD "<" PREVIOUS_DUTY_CYCLE
#
#    set_period
#  else #if [[ $PREVIOUS_PERIOD < $DUTY_CYCLE_NANOSEC ]]
#    echo PREVIOUS_PERIOD "<" DUTY_CYCLE_NANOSEC
#    set_period
#    set_duty_cycle
#  fi

  set_duty_cycle 0 # resolves illegal conflicts
  set_period $PERIOD
  set_duty_cycle $DUTY_CYCLE_NANOSEC
  do_operation
}

help()
{
  cat << EOF
  A utility for controlling hardware PWM on raspberry pi.
  Author: Ben Steinberg (2022).

  USAGE: $0 <options>

  options:

    -f|--frequency)
      In Hz.
      The kernel module technically allows to set max frequency =~ 67 [Mhz] (T = 15 [ns] ), and no minimum.
      In practice I could not get a frequency lower than 1 Hz, And I haven't tested the max yet (as of 5.02.2022).
      Theoretically this frequency is derived from the "oscillator" (some cristal oscillator?) which runs at 19.2 Mhz
      and uses a 12 bit devisor (probably implemented as a FF counter) with max value 4095. This means that we should
      be able to generated frequencies between 4688 Hz and 19.2 Mhz. Some sources state unexpected behaviour
      with frequencies below 4688Hz and above 9.6Mhz (19.2 / 2).

      See:
      https://youngkin.github.io/post/pulsewidthmodulationraspberrypi/#overview-of-pwm-on-a-raspberry-pi-3b


    -dc|--duty-cycle)
      In % 0 - 100.

    -c|--channel)
      0 or 1.
      The bcm 2837b0 offers 2 PWM channels availabe on 2 pins each, chan 0: 18/12, chan 1: 19/13
      (actually this was true for bcm 2835 and 2837 may offer a few more pins, I'm not sure.)

    -op||--operation)
      one of:
        ENABLE - turns channel on
        DISABLE - turns channel off.
EOF
}

arg_parse()
{
  #defaults
  FREQUENCY=10000
  DUTY_CYCLE=50
  CHANNEL=0
  OPERATION="enable"

  while [[ $# -gt 0 ]]; do
    case $1 in
      -f|--frequency)
        FREQUENCY="$2"
        shift # past argument
        shift # past value
        ;;
      -dc|--duty-cycle)
        DUTY_CYCLE="$2"
        shift # past argument
        shift # past value
        ;;
      -c|--channel)
        CHANNEL="$2"
        shift # past argument
        shift # past value
        ;;
      -op|--operation)
         OPERATION="$2"
         if [[ "$OPERATION" == "ENABLE" || "$OPERATION" == "DISABLE" || "$OPERATION" == 0 || "$OPERATION" == 1 ]]
         then
            shift # past argument
            shift # past value
         else
            exit 1
         fi
        ;;
      -*|--*)
        help
        exit 1
        ;;
      -h|--help)
        help
        exit 1
        ;;
    esac
  done


}

export_channel()
{
  echo $CHANNEL  > /sys/class/pwm/pwmchip0/export
}


set_period()
{
  while [[ `cat /sys/class/pwm/pwmchip0/pwm$CHANNEL/period` != $1 ]]
  do
    echo $1 > /sys/class/pwm/pwmchip0/pwm$CHANNEL/period
  done

  printf "PERIOD=%d[ns]\t" $1
}


set_duty_cycle()
{
  while [[ `cat /sys/class/pwm/pwmchip0/pwm0/duty_cycle` != $1 ]]
  do
    echo $1 > /sys/class/pwm/pwmchip0/pwm0/duty_cycle
  done

  printf "DUTY_CYCLE=%d[ns]\t" $1
}

do_operation()
{
  if [[ "$OPERATION" == "ENABLE" || "$OPERATION" == 1 ]]
  then
    echo 1 > /sys/class/pwm/pwmchip0/pwm$CHANNEL/enable
    echo enabled
  else
    echo 0 > /sys/class/pwm/pwmchip0/pwm$CHANNEL/enable
    echo disabled
  fi
}

main "$@"