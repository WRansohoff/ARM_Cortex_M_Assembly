#ifndef _VVC_VECT_TBL
#define _VVC_VECT_TBL

.syntax unified
.cpu cortex-m4
.fpu softvfp
.thumb

// Global values.
.global reset_handler

/*
 * Define the core vector table which will live at 0x[8]0000000.
 * This will depend on the specific chip you are using, but
 * some things like the end-of-stack address, reset handler,
 * etc. are unlikely to change.
 * Still, for peripheral stuff, refer to your datasheet. Your
 * chip's vendor may also provide a template startup file,
 * where you can probably verify the values/addresses.
 */
.section .isr_vector,"a",%progbits
.type vector_table, %object
.size vector_table, .-vector_table
vector_table:
    // 0-15
    .word _estack
    .word reset_handler
    .word NMI_handler
    .word hard_fault_handler
    .word memory_management_handler
    .word bus_fault_handler
    .word usage_fault_handler
    .word 0
    .word 0
    .word 0
    .word 0
    .word SVC_handler
    .word debug_monitor_handler
    .word 0
    .word pending_SV_handler
    .word SysTick_handler
    // 16-31.
    // I just call IRQ handlers 'interrupts.'
    .word window_watchdog_interrupt
    .word programmable_voltage_interrupt
    .word tamper_event_interrupt
    .word RTC_wakeup_interrupt
    .word flash_interrupt
    .word RCC_interrupt
    .word EXTI0_interrupt
    .word EXTI1_interrupt
    .word EXTI2_TS_interrupt
    .word EXTI3_interrupt
    .word EXTI4_interrupt
    .word DMA1_chan1_interrupt
    .word DMA1_chan2_interrupt
    .word DMA1_chan3_interrupt
    .word DMA1_chan4_interrupt
    .word DMA1_chan5_interrupt
    // 32-47
    .word DMA1_chan6_interrupt
    .word DMA1_chan7_interrupt
    .word ADC1_2_interrupt
    .word USB_P_CAN1_TX_interrupt
    .word USB_M_CAN1_RX0_interrupt
    .word CAN1_RX1_interrupt
    .word CAN1_SCE_interrupt
    .word EXTI_9_5_interrupt
    .word TIM1_BRK_TIM15_interrupt
    .word TIM1_UP_TIM16_interrupt
    .word TIM1_COM_TIM17_interrupt
    .word TIM1_CC_interrupt
    .word TIM2_interrupt
    .word TIM3_interrupt
    .word TIM4_interrupt
    .word I2C1_EV_interrupt
    // 48-63
    .word I2C1_ER_interrupt
    .word I2C2_EV_interrupt
    .word I2C2_ER_interrupt
    .word SPI1_interrupt
    .word SPI2_interrupt
    .word USART1_interrupt
    .word USART2_interrupt
    .word USART3_interrupt
    .word EXTI15_10_interrupt
    .word RTC_alarm_interrupt
    .word USB_wakeup_interrupt
    .word TIM8_BRK_interrupt
    .word TIM8_UP_interrupt
    .word TIM8_TRG_COM_interrupt
    .word TIM8_CC_interrupt
    .word ADC3_interrupt
    // 64-71
    .word 0
    .word 0
    .word 0
    .word SPI3_interrupt
    .word UART4_interrupt
    .word UART5_interrupt
    .word TIM6_DAC_interrupt
    .word TIM7_interrupt
    .word DMA2_chan1_interrupt
    .word DMA2_chan2_interrupt
    .word DMA2_chan3_interrupt
    .word DMA2_chan4_interrupt
    .word DMA2_chan5_interrupt
    .word ADC4_interrupt
    .word 0
    .word 0
    // 72-87
    .word COMP_1_2_3_interrupt
    .word COMP_4_5_6_interrupt
    .word COMP_7_interrupt
    .word 0
    .word 0
    .word 0
    .word 0
    .word 0
    .word 0
    .word 0
    .word USB_p_interrupt
    .word USB_m_interrupt
    .word 0
    .word 0
    .word 0
    .word 0
    .word FPU_interrupt

    /*
     * Setup weak aliases for each exception handler to the
     * default one. These can be updated later, or just
     * overridden since they're weak refs.
     * The reset_handler is set up separately.
     */
    // 0-15
    .weak NMI_handler
    .thumb_set NMI_handler, default_interrupt_handler
    .weak hard_fault_handler
    .thumb_set hard_fault_handler, default_interrupt_handler
    .weak memory_management_handler
    .thumb_set memory_management_handler, default_interrupt_handler
    .weak bus_fault_handler
    .thumb_set bus_fault_handler, default_interrupt_handler
    .weak usage_fault_handler
    .thumb_set usage_fault_handler, default_interrupt_handler
    .weak SVC_handler
    .thumb_set SVC_handler, default_interrupt_handler
    .weak debug_monitor_handler
    .thumb_set debug_monitor_handler, default_interrupt_handler
    .weak pending_SV_handler
    .thumb_set pending_SV_handler, default_interrupt_handler
    .weak SysTick_handler
    .thumb_set SysTick_handler, default_interrupt_handler
    // 16-31
    .weak window_watchdog_interrupt
    .thumb_set window_watchdog_interrupt, default_interrupt_handler
    .weak programmable_voltage_interrupt
    .thumb_set programmable_voltage_interrupt, default_interrupt_handler
    .weak tamper_event_interrupt
    .thumb_set tamper_event_interrupt, default_interrupt_handler
    .weak RTC_wakeup_interrupt
    .thumb_set RTC_wakeup_interrupt, default_interrupt_handler
    .weak flash_interrupt
    .thumb_set flash_interrupt, default_interrupt_handler
    .weak RCC_interrupt
    .thumb_set RCC_interrupt, default_interrupt_handler
    .weak EXTI0_interrupt
    .thumb_set EXTI0_interrupt, default_interrupt_handler
    .weak EXTI1_interrupt
    .thumb_set EXTI1_interrupt, default_interrupt_handler
    .weak EXTI2_TS_interrupt
    .thumb_set EXTI2_TS_interrupt, default_interrupt_handler
    .weak EXTI3_interrupt
    .thumb_set EXTI3_interrupt, default_interrupt_handler
    .weak EXTI4_interrupt
    .thumb_set EXTI4_interrupt, default_interrupt_handler
    .weak DMA1_chan1_interrupt
    .thumb_set DMA1_chan1_interrupt, default_interrupt_handler
    .weak DMA1_chan2_interrupt
    .thumb_set DMA1_chan2_interrupt, default_interrupt_handler
    .weak DMA1_chan3_interrupt
    .thumb_set DMA1_chan3_interrupt, default_interrupt_handler
    .weak DMA1_chan4_interrupt
    .thumb_set DMA1_chan4_interrupt, default_interrupt_handler
    .weak DMA1_chan5_interrupt
    .thumb_set DMA1_chan5_interrupt, default_interrupt_handler
    // 32-47
    .weak DMA1_chan6_interrupt
    .thumb_set DMA1_chan6_interrupt, default_interrupt_handler
    .weak DMA1_chan7_interrupt
    .thumb_set DMA1_chan7_interrupt, default_interrupt_handler
    .weak ADC1_2_interrupt
    .thumb_set ADC1_2_interrupt, default_interrupt_handler
    .weak USB_P_CAN1_TX_interrupt
    .thumb_set USB_P_CAN1_TX_interrupt, default_interrupt_handler
    .weak USB_M_CAN1_RX0_interrupt
    .thumb_set USB_M_CAN1_RX0_interrupt, default_interrupt_handler
    .weak CAN1_RX1_interrupt
    .thumb_set CAN1_RX1_interrupt, default_interrupt_handler
    .weak CAN1_SCE_interrupt
    .thumb_set CAN1_SCE_interrupt, default_interrupt_handler
    .weak EXTI_9_5_interrupt
    .thumb_set EXTI_9_5_interrupt, default_interrupt_handler
    .weak TIM1_BRK_TIM15_interrupt
    .thumb_set TIM1_BRK_TIM15_interrupt, default_interrupt_handler
    .weak TIM1_UP_TIM16_interrupt
    .thumb_set TIM1_UP_TIM16_interrupt, default_interrupt_handler
    .weak TIM1_COM_TIM17_interrupt
    .thumb_set TIM1_COM_TIM17_interrupt, default_interrupt_handler
    .weak TIM1_CC_interrupt
    .thumb_set TIM1_CC_interrupt, default_interrupt_handler
    .weak TIM2_interrupt
    .thumb_set TIM2_interrupt, default_interrupt_handler
    .weak TIM3_interrupt
    .thumb_set TIM3_interrupt, default_interrupt_handler
    .weak TIM4_interrupt
    .thumb_set TIM4_interrupt, default_interrupt_handler
    .weak I2C1_EV_interrupt
    .thumb_set I2C1_EV_interrupt, default_interrupt_handler
    // 48-63
    .weak I2C1_ER_interrupt
    .thumb_set I2C1_ER_interrupt, default_interrupt_handler
    .weak I2C2_EV_interrupt
    .thumb_set I2C2_EV_interrupt, default_interrupt_handler
    .weak I2C2_ER_interrupt
    .thumb_set I2C2_ER_interrupt, default_interrupt_handler
    .weak SPI1_interrupt
    .thumb_set SPI1_interrupt, default_interrupt_handler
    .weak SPI2_interrupt
    .thumb_set SPI2_interrupt, default_interrupt_handler
    .weak USART1_interrupt
    .thumb_set USART1_interrupt, default_interrupt_handler
    .weak USART2_interrupt
    .thumb_set USART2_interrupt, default_interrupt_handler
    .weak USART3_interrupt
    .thumb_set USART3_interrupt, default_interrupt_handler
    .weak EXTI15_10_interrupt
    .thumb_set EXTI15_10_interrupt, default_interrupt_handler
    .weak RTC_alarm_interrupt
    .thumb_set RTC_alarm_interrupt, default_interrupt_handler
    .weak USB_wakeup_interrupt
    .thumb_set USB_wakeup_interrupt, default_interrupt_handler
    .weak TIM8_BRK_interrupt
    .thumb_set TIM8_BRK_interrupt, default_interrupt_handler
    .weak TIM8_UP_interrupt
    .thumb_set TIM8_UP_interrupt, default_interrupt_handler
    .weak TIM8_TRG_COM_interrupt
    .thumb_set TIM8_TRG_COM_interrupt, default_interrupt_handler
    .weak TIM8_CC_interrupt
    .thumb_set TIM8_CC_interrupt, default_interrupt_handler
    .weak ADC3_interrupt
    .thumb_set ADC3_interrupt, default_interrupt_handler
    // 64-71
    .weak SPI3_interrupt
    .thumb_set SPI3_interrupt, default_interrupt_handler
    .weak UART4_interrupt
    .thumb_set UART4_interrupt, default_interrupt_handler
    .weak UART5_interrupt
    .thumb_set UART5_interrupt, default_interrupt_handler
    .weak TIM6_DAC_interrupt
    .thumb_set TIM6_DAC_interrupt, default_interrupt_handler
    .weak TIM7_interrupt
    .thumb_set TIM7_interrupt, default_interrupt_handler
    .weak DMA2_chan1_interrupt
    .thumb_set DMA2_chan1_interrupt, default_interrupt_handler
    .weak DMA2_chan2_interrupt
    .thumb_set DMA2_chan2_interrupt, default_interrupt_handler
    .weak DMA2_chan3_interrupt
    .thumb_set DMA2_chan3_interrupt, default_interrupt_handler
    .weak DMA2_chan4_interrupt
    .thumb_set DMA2_chan4_interrupt, default_interrupt_handler
    .weak DMA2_chan5_interrupt
    .thumb_set DMA2_chan5_interrupt, default_interrupt_handler
    .weak ADC4_interrupt
    .thumb_set ADC4_interrupt, default_interrupt_handler
    // 72-87
    .weak COMP_1_2_3_interrupt
    .thumb_set COMP_1_2_3_interrupt, default_interrupt_handler
    .weak COMP_4_5_6_interrupt
    .thumb_set COMP_4_5_6_interrupt, default_interrupt_handler
    .weak COMP_7_interrupt
    .thumb_set COMP_7_interrupt, default_interrupt_handler
    .weak USB_p_interrupt
    .thumb_set USB_p_interrupt, default_interrupt_handler
    .weak USB_m_interrupt
    .thumb_set USB_m_interrupt, default_interrupt_handler
    .weak FPU_interrupt
    .thumb_set FPU_interrupt, default_interrupt_handler

/*
 * A 'Default' interrupt handler. This is where interrupts
 * which are not otherwise configured will go.
 * It is an infinite loop, because...well, clearly we weren't
 * expecting the interrupt, so what can we do?
 */
.section .text.default_interrupt_handler,"ax",%progbits
default_interrupt_handler:
    default_interrupt_loop:
      B default_interrupt_loop
.size default_interrupt_handler, .-default_interrupt_handler

#endif
