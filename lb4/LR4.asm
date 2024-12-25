.model small
.stack 1024  ; 1KB стека

.data
	; строки приветствия, ожидания, ввода и вывода
    msg_greeting db 'Welcome! This program created by Ksenia Kopasova 3382.$'
    msg_enter_string db 0Dh, 0Ah, 'Enter a string: $' ; для организации задержки, для ввода данных не используется
    msg_wait db 0Dh, 0Ah, 'Press enter for result: $' ; для организации задержки, для ввода данных не используется
	input_str db 80, ?, 83 dup(?) ;сохраняем введенную пользователем строку
    output_str db 83 dup('$') ; модифициаронная строка 
    result db 0Dh, 0Ah, 'The resulting string: $' ; перед выводом строки
	timer_counter dw 0 ; счетчик тиков таймера
	tick_counter dw 0 ; счетчик тиков
	save_int_1ch dd ? ; хранение оригинального обработчика 60h
    save_int_4bh dd ? ; хранение оригинального обработчика 1ch
	
.code
main:
	; инициализация сегмента данных
    mov ax, @data 
    mov ds, ax 
    mov es, ax ; инициализация доп сегмента es 
	; тк некоторые инструкции (например, stosb) используют дополнительный сегмент es 
	; для указания адреса назначения
	; так же инициализация es позволяет корректно записывать данные в буфер
	
	; вывод приветствия
    mov ah, 09h ; функция вывода строки
    lea dx, msg_greeting ; строка-приветствие, которую надо вывести 
    int 21h ; вызов прерывание дос, которое выполняет функцию из ah
	
	mov ah, 09h ; функция вывода строки
	lea dx, msg_enter_string ; строка, которую нужно вывести
	int 21h ; вызов прерывания дос, которое выполняет прерывание из ah
	
	; ввод строки с ограничением длины
    mov ah, 0Ah ; команда для ввода строки с ограничением длины
    lea dx, input_str ; загружаем адрес буфера в регистр dx 
    int 21h ; вызов прерывание дос, которое выполняет программу из ah
	
	; сохраняем 4bh
	mov ax, 354bh ; функция дос для получения адреса обработчика прерывания
	int 21h ; вызов прерывания дос
	; теперь адрес изначального обработчика 4bh содержится в bx (смещение) и cx (сегмент)
	mov word ptr save_int_4bh, bx ; сохраняем смещение прерывания 
	mov word ptr save_int_4bh+2, es ; сохраняем сегмент прерывания
	
	; сохранение и замена 1ch
	mov ax, 351ch ; узнаем адрес текущего обработчика прерывания 1ch (таймер) 
	int 21h ; вызываем команду из ax 
	; теперь адрес изначального обработчика содержится в bx (смещение) и cx (сегмент)
	mov word ptr save_int_1ch, bx ; сохраняем смещение обработчика 1ch
	mov word ptr save_int_1ch+2, es ; сохраняем сегмент обработчика 1ch
	
	push ds ; сохраняем текущий ds в стеке
	mov dx, offset new_int_1ch  ; записываем в dx смещение нового обработчика 1ch 
	mov ax, seg new_int_1ch ; записываем в ax сегмент нового обработчика 1ch
	mov ds, ax ; помещаем сегмент нового обработчика 1ch в сегмент данных 
	mov ax, 251ch; функция дос для установки нового обработчика 1ch (25 - вектор постановки адреса обработчика)
	int 21h ; вызов дос для установки нового обработчика 1ch
	pop ds ; достаем обратно дата сегмент 
	
	; ввод строки 
    mov ah, 09h ; функция дос для ввода строки 
    lea dx, msg_wait ; загружает адрес буфера в регистр dx
    int 21h ;вызывает прерывание дос, которое выполняет функцию, указанную в ah
	
	; ввод до тох пор, пока нажатая клавиша != Enter
wait_proc:
	mov ah, 01h ; функция для проверки нажатой клавиши
	int 21h ; вызов дос
	cmp al, 0Dh ; проверяем, была ли нажата клаваша Enter
	jne wait_proc ; если al != Enter, то переходим по метке wait_proc
	
	; вызов 4bh
	int 4bh
	
	; восстанавливаем старый обработчик 4bh
	mov ax, 254bh ; уставновим вектор прерывания 4bh в регистр ax
	lds dx, save_int_4bh ; ; загрузим адрес исходного(сохраненного) обработчика прерывания
	; 4bh (сохранен в переменной save_int_4bh) в регистры ds:dx
	int 21h ; выполняем фукнцию 25h, устанавливая вектор прерывания 4bh на адрес, сохраненный в ds:dx
	push ds ; загружаем регистр ds в стек
	mov ax, @data 
	mov ds, ax ; восстанавливаем дата сегмент
	
	; восстанавливаем 1ch
	mov ax, 251ch ; уставновим вектор прерывания 1ch в регистр ax
	lds dx, save_int_1ch ; загрузим адрес исходного(сохраненного) обработчика прерывания
	; 1ch (сохранен в переменной save_int_1ch) в регистры ds:dx
	int 21h ; выполняем фукнцию 25h, устанавливая вектор прерывания 1сh на адрес, сохраненный в ds:dx
	push ds ; загружаем регистр ds в стек
	mov ax, @data 
	mov ds, ax ; восстанавливаем дата сегмент
	
	; завершение программы
	mov ax, 4c00h ; функция дос для завершения программы
	int 21h ; Вызов прерывания DOS, который завершит программу

;новый обработчик 1ch	
new_int_1ch proc far
; far - это дальняя процедура и она может быть вызвана из другого сегмента кода
; обработчики прерываний должны быть дальними процедурами
	; сохраняем, поскольку далее данные регистры будут менятся
	push ax ; сохраняем ax в стеке
 	push ds ; сохраняем ds в стеке
	
	mov ax, @data 
	mov ds, ax ; опредляем дс как дата сегмент
	
	inc timer_counter ; timer_counter + 1 количество вызовов 1ch (inc - инкремент - добавляет к числу 1)
	inc tick_counter ; tick_counter + 1 - количество тиков с момента установки нового обработчика
	
	cmp tick_counter, 55 ; ~ 3 секунды (18,2 * 3), тк прерывание в 1ch генерируется 18.2 раз в секунду
	jb check_restore ; переход по метке check_restore, если меньше 3 секунду
	
	; меняем 4bh, если он не был изменен раньше 
	push ds ; сохраняем дата сегмент в стеке
	mov dx, offset new_int_4bh ; загружаем адрес нового обработчика 4bh в bx
	mov ax, seg new_int_4bh ; загружаем сегмент нового обработчика 4bh
	mov ds, ax ; загружаем сегмент нового обработчика 4bh в дата сегмент 
	mov ax, 254bh ; функция дос для установки нового обработчика 4bh
	int 21h ; вызов дос
	pop ds ; достаем из стека дата сегмент
	
check_restore:
; с момента установки нового обработчика прошло <3 секунд
; ничего не восстанавливаем
	; восстанавливаем регистры в соответвующем порядке ds и ax	
	pop ds 
	pop ax 
	iret ; (interrupt return) завершаем обработчик прерывания
	;извлекает cs:ip из стека: загружает значение cs и ip из стека, 
	; восстанавливая адрес возвратав прерванную прог.
	;извлекает флаги из стека: восстанавливает регистр флага из стека
	;возвращает управление: процессов продолжает выполнение программы с адреса, 
	;указанного в восстановленных cs:ip
new_int_1ch endp

;новый обработчик 4bh - выполняет обработку строки(удаление цифр в строке), 
;выводит ее и восстанавливает себя
new_int_4bh proc far
	; сохраняем значения регистров ax, bx, cx, dx, si, di, ds, ed на стеке
	;чтобы не повредить их значение при выполнении процедуры
	push ax
	push bx
	push cx
	push dx
	
	mov ax, @data 
	mov ds, ax
	mov es, ax ; устанавливаем доп сегмент es
	
	; получаем длину строки
	xor cx, cx ; обнуляем регистр cx
	mov cl, input_str+1 ; загружаем длину введеной строки из input_str+1
	;(там хранится фактическая длина строки)
	; настраиваем указатели
	lea si, input_str+2 ; источник - входная строка
	lea di, output_str ; назначение - выходная строка

processing_cycle:
	or cx, cx ; устанавливаем флаги в соответствии с содержимым в cx
	; zf = 1, если cx = 0
	jz finish_proc ; переход к метке, если zf = 1 (cx = 0, те все символы обработаны)
	
	lodsb ; загружает байт из адреса ds:si в al и инкрементирует в si
	
	; проверяем, является ли символ цифрой 
	cmp al, '0' ; сравниваем al (текущий символ) с кодом символа '0'
	jb not_digit; если символ меньше нуля, то это не цифра
	
	cmp al, '9' ; сравниваем al (текущий символ) с кодом символа '9'
	ja not_digit; если символ больше девятки, то это тоже не цифра
	
	;если это все же цифра, то пропускаем ее и переходим к следующему символу
	dec cx ; декрементируем cx (счетчик символов)
	jmp processing_cycle ; переходим к метке processing_cycle
	
not_digit: ; если символ != цифре	
	stosb ; сохраняем байт из al по адресу es:di и инкрементируем di
	dec cx ; декрементируем cx (счетчик символов)
	jmp processing_cycle ; снова переходим по метке processing_cycle
	
finish_proc: ; если строка закончилась
	; добавляем завершающие символы
	mov al, 0Dh ; загружаем в al символ возврата каретки
	stosb ; сохраняем байт из al по адресу es:di и инкрементируем di
	mov al, 0Ah ; загружаем в al символ перевода курсора 
	stosb ; сохраняем байт из al по адресу es:di и инкрементируем di
	mov al, '$' ; загружаем в al символ конца строки
	stosb ; сохраняем байт из al по адресу es:di и инкрементируем di
	
	; выводим результат
	mov ah, 09h; загружаем функцию вывода строки в регистр ah
	lea dx, result ; загружаем адрес строки result в регистр dx
	int 21h ; вызов дос
	
	mov ah, 09h ; загружаем фукнцию вывода строки в регистр ah
	lea dx, output_str ; загружаем адрес строки output_str в регистр dx
	int 21h ; вызов дос

	; восстанавливаем регистры в обратном порядке их сохранения
	pop dx
	pop cx
	pop bx
	pop ax	
	iret ; выходим из обработчика прерывания
new_int_4bh endp

end main