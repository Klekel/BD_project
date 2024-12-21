from pathlib import Path
from tkinter import Tk, Canvas, Entry, Text, Button, PhotoImage, messagebox
from tkinter import ttk, messagebox
import psycopg2
import random

def connect_to_db():
    try:
        return psycopg2.connect(
            dbname="project",
            user="postgres",
            password="postgres",
            host="localhost",
            port="5432"
        )
    except Exception as e:
        messagebox.showerror("Ошибка подключения", str(e))
        return None

def login_user(email, password, db_connection):
    try:
        cursor = db_connection.cursor()
        query = "select user_id from check_user(%s,%s)"
        cursor.execute(query, (email, password))
        user = cursor.fetchone()
        cursor.close()
        if user:
            return user
        else:
            return None
    except Exception as e:
        messagebox.showerror("Ошибка", str(e))
        return None

def open_second_window(db_connection):
    window.destroy()
    create_second_window(db_connection)

def create_first_window():
    global window
    OUTPUT_PATH = Path(__file__).parent
    ASSETS_PATH = OUTPUT_PATH / Path(r"assets/frame0")

    def relative_to_assets(path: str) -> Path:
        return ASSETS_PATH / Path(path)

    def try_login():
        email = email_entry.get()
        password = password_entry.get()
        user = login_user(email, password, db_connection)
        if user:
            window.destroy()  # Закрываем первое окно
            open_raspisanie_window(user, db_connection)
        else:
            messagebox.showerror("Ошибка", "Неверные учетные данные.")

    db_connection = connect_to_db()
    if not db_connection:
        return

    window = Tk()
    window.geometry("833x507")
    window.configure(bg="#000000")

    canvas = Canvas( window, bg="#000000", height=507, width=833, bd=0, highlightthickness=0, relief="ridge")
    canvas.place(x=0, y=0)
    canvas.create_rectangle( 1.0, 0.0, 834.0, 507.0, fill="#474747", outline="" )

    image_image_1 = PhotoImage(file=relative_to_assets("image_1.png"))
    image_1 = canvas.create_image(416.0, 53.0, image=image_image_1)

    entry_image_1 = PhotoImage(file=relative_to_assets("entry_1.png"))
    entry_bg_1 = canvas.create_image(411.5, 330.5, image=entry_image_1)
    password_entry = Entry( bd=0, bg="#474747", fg="#000716", highlightthickness=0, foreground="white" )
    password_entry.place(x=282, y=303.0, width=258.0, height=57.0)

    image_image_2 = PhotoImage(file=relative_to_assets("image_2.png"))
    image_2 = canvas.create_image(602.0, 233.0, image=image_image_2)

    image_image_3 = PhotoImage(file=relative_to_assets("image_3.png"))
    image_3 = canvas.create_image(602.0, 331.0, image=image_image_3)

    button_image_1 = PhotoImage(file=relative_to_assets("button_1.png"))
    button_1 = Button( image=button_image_1, borderwidth=0, highlightthickness=0, command=lambda: open_second_window(db_connection), relief="flat" )
    button_1.place(x=209.0, y=424.0, width=151.0, height=32.0)

    entry_image_2 = PhotoImage(file=relative_to_assets("entry_2.png"))
    entry_bg_2 = canvas.create_image(411.5, 233.5, image=entry_image_2)
    email_entry = Entry( bd=0, bg="#474747", fg="#000716", highlightthickness=0 , foreground="white")
    email_entry.place(x=282, y=206.0, width=258.0, height=57.0)

    button_image_2 = PhotoImage(file=relative_to_assets("button_2.png"))
    button_2 = Button( image=button_image_2, borderwidth=0, highlightthickness=0, command=try_login, relief="flat" )
    button_2.place(x=454.0, y=418.0, width=117.0, height=52.0)

    canvas.create_text( 259.0, 13.0, anchor="nw", text="Авторизация", fill="#000000", font=("Fruktur Regular", 48 * -1) )
    window.resizable(False, False)
    window.mainloop()

def create_second_window(db_connection):
    global window
    OUTPUT_PATH = Path(__file__).parent
    ASSETS_PATH = OUTPUT_PATH / Path(r"assets/frame1")

    def register_user(db_connection):
        first_name = first_name_entry.get()
        last_name = last_name_entry.get()
        email = email_entry.get()
        phone_number = phone_number_entry.get()
        transport_concession = concession_combo.get()
        password = password_entry.get()

        if not first_name or not last_name or not email or not phone_number or not transport_concession or not password:
            messagebox.showerror("Ошибка", "Заполните все поля!")
            return

        try:
            cursor = db_connection.cursor()
            query = "CALL add_user(%s, %s, %s, %s, %s, %s, %s)"
            cursor.execute(query, (first_name, last_name, email, phone_number, random.randint(100, 1000), password, transport_concession))
            db_connection.commit()

            cursor.execute("select user_id from get_user_id(%s)", (email,))
            user_id = cursor.fetchone()
            cursor.close()

            messagebox.showinfo("Успешно", "Регистрация прошла успешно!")
            window.destroy()
            open_raspisanie_window( user_id, db_connection)

        except Exception as e:
            messagebox.showerror("Ошибка", str(e))

    def relative_to_assets(path: str) -> Path:
        return ASSETS_PATH / Path(path)

    window = Tk()
    window.geometry("833x507")
    window.configure(bg="#474747")

    canvas = Canvas( window, bg="#474747", height=507, width=833, bd=0, highlightthickness=0, relief="ridge" )
    canvas.place(x=0, y=0)

    entry_image_1 = PhotoImage(file=relative_to_assets("entry_1.png"))
    entry_bg_1 = canvas.create_image(419.5, 146.5, image=entry_image_1)
    first_name_entry = Entry( bd=0, bg="#474747", fg="#000716", highlightthickness=0,foreground="white" )
    first_name_entry.place(x=286.0, y=119.0, width=267.0, height=55.0)

    entry_image_2 = PhotoImage(file=relative_to_assets("entry_2.png"))
    entry_bg_2 = canvas.create_image(420.5, 266.5, image=entry_image_2)
    email_entry = Entry( bd=0, bg="#474747", fg="#000716", highlightthickness=0 ,foreground="white")
    email_entry.place(x=286.0, y=239.0, width=267.0, height=55.0)

    image_image_1 = PhotoImage(file=relative_to_assets("image_1.png"))
    image_1 = canvas.create_image(615.0, 267.0, image=image_image_1)

    entry_image_3 = PhotoImage(file=relative_to_assets("entry_3.png"))
    entry_bg_3 = canvas.create_image(419.5, 206.5, image=entry_image_3)
    last_name_entry = Entry( bd=0, bg="#474747", fg="#000716", highlightthickness=0,foreground="white" )
    last_name_entry.place(x=286.0, y=179.0, width=267.0, height=55.0)

    entry_image_4 = PhotoImage(file=relative_to_assets("entry_4.png"))
    entry_bg_4 = canvas.create_image(421.5, 326.5, image=entry_image_4)
    phone_number_entry = Entry( bd=0, bg="#474747", fg="#000716", highlightthickness=0 ,foreground="white")
    phone_number_entry.place(x=286.0, y=299.0, width=267.0, height=55.0)

    image_image_2 = PhotoImage(file=relative_to_assets("image_2.png"))
    image_2 = canvas.create_image(615.0, 327.0, image=image_image_2)

    entry_image_5 = PhotoImage(file=relative_to_assets("entry_5.png"))
    entry_bg_5 = canvas.create_image(422.5, 446.5, image=entry_image_5)
    password_entry = Entry( bd=0, bg="#474747", fg="#000716", highlightthickness=0 ,foreground="white")
    password_entry.place(x=286.0, y=419.0, width=267.0, height=55.0)

    image_image_3 = PhotoImage(file=relative_to_assets("image_3.png"))
    image_3 = canvas.create_image(615.0, 447.0, image=image_image_3)

    entry_image_6 = PhotoImage(file=relative_to_assets("entry_6.png"))
    entry_bg_6 = canvas.create_image(421.5, 386.5, image=entry_image_6)
    concession = [ "без льгот", "пол цены", "бесплатно"]
    style = ttk.Style()
    style.theme_use("default")
    style.configure("TCombobox", fieldbackground="#474747", background="#474747", foreground="white", selectbackground="#474747", selectforeground="white", font=("Fruktur Regular", 48 * -1))
    concession_combo = ttk.Combobox(window,background="#474747", values=concession)
    concession_combo.place(x=286.0, y=359.0, width=267.0, height=55.0)

    canvas.create_text( 169.0, 117.0, anchor="nw", text="Имя", fill="#FFFFFF", font=("Fruktur Regular", 36 * -1) )

    canvas.create_text(78.0,176.0,anchor="nw",text="Фамилия",fill="#FFFFFF",font=("Fruktur Regular", 36 * -1))

    canvas.create_text( 128.0, 237.0, anchor="nw", text="Почта", fill="#FFFFFF", font=("Fruktur Regular", 36 * -1) )

    canvas.create_text( 80.0, 296.0, anchor="nw", text="Телефон", fill="#FFFFFF", font=("Fruktur Regular", 36 * -1) )

    canvas.create_text( 117.0, 356.0, anchor="nw", text="Льгота", fill="#FFFFFF", font=("Fruktur Regular", 36 * -1) )

    image_image_4 = PhotoImage(file=relative_to_assets("image_4.png"))
    image_4 = canvas.create_image(416.0, 53.0, image=image_image_4)

    canvas.create_text( 263.0, 15.0, anchor="nw", text="Регистрация", fill="#000000", font=("Fruktur Regular", 48 * -1) )

    canvas.create_text( 108.0, 417.0, anchor="nw", text="Пароль", fill="#FFFFFF", font=("Fruktur Regular", 36 * -1) )

    button_image_1 = PhotoImage(file=relative_to_assets("button_1.png"))
    button_1 = Button( image=button_image_1, borderwidth=0, highlightthickness=0, command=lambda: register_user(db_connection), relief="flat" )
    button_1.place(x=671.0, y=423.0, width=117.0, height=52.0)

    window.resizable(False, False)
    window.mainloop()

def open_lychny_kabinet_window(user_id, db_connection):
    OUTPUT_PATH = Path(__file__).parent
    ASSETS_PATH = OUTPUT_PATH / Path(r"assets/frame2")

    def relative_to_assets(path: str) -> Path:
        return ASSETS_PATH / Path(path)

    lych_kab = Tk()

    lych_kab.geometry("833x507")
    lych_kab.configure(bg = "#474747")

    def load_user_info():
        cursor = db_connection.cursor()
        cursor.execute("SELECT first_name, last_name, money FROM get_user_name(%s)", (user_id,))
        user_info = cursor.fetchone()
        cursor.close()
        return user_info

    def update_balance():
        amount = entry_1.get()
        if not amount.isdigit() or int(amount) < 0:
            messagebox.showerror("Ошибка", "Введите неотрицательное целое число!")
            return

        try:
            cursor = db_connection.cursor()
            cursor.execute("CALL add_users_money(%s,%s)", (user_id, int(amount)))
            db_connection.commit()
            cursor.close()
            messagebox.showinfo("Успешно", f"Баланс пополнен на {amount}!")
            user_info = load_user_info()
            canvas.itemconfig(tagOrId=money, text = user_info[2])
        except Exception as e:
            messagebox.showerror("Ошибка", str(e))

    def view_tickets():
        cursor = db_connection.cursor()
        cursor.execute("select * from get_tickets(%s)", (user_id,))
        tickets = cursor.fetchall()
        cursor.close()

        if not tickets:
            messagebox.showinfo("Информация", "У вас нет купленных билетов.")
            return

        ticket_window = Tk()
        ticket_window.title("Купленные билеты")

        style = ttk.Style(ticket_window)
        style.theme_use("default")

        style.configure("Treeview", background="#FFBF87", fieldbackground="#FFBF87", foreground="black")
        style.configure("Treeview.Heading", background="#FFBF87", fieldbackground="#FFBF87", foreground="black")

        columns = ("ticket_id", "user_id", "route_id", "from_station_id", "to_station_id", "date", "price", "total_price", "train_type")
        tree = ttk.Treeview(ticket_window, columns=columns, show="headings", height=10)

        for col in columns:
            tree.heading(col, text=col)
            tree.column(col, anchor="center", width=100)

        for ticket in tickets:
            tree.insert("", "end", values=ticket)

        tree.pack(fill="both", expand=True)

        ticket_window.mainloop()

    def delete_account():
            confirm = messagebox.askyesno("Подтверждение", "Вы уверены, что хотите удалить аккаунт?")
            if confirm:
                try:
                    cursor = db_connection.cursor()
                    cursor.execute("CALL delete_tickets(%s)", (user_id,))
                    db_connection.commit()

                    cursor.execute("CALL delete_user(%s)", (user_id,))
                    db_connection.commit()
                    cursor.close()

                    messagebox.showinfo("Успешно", "Аккаунт и все купленные билеты удалены!")
                    lych_kab.destroy()
                    create_first_window()
                except Exception as e:
                    messagebox.showerror("Ошибка", str(e))

    def open_rasp_window_f_lk(user_id,db_connection):
      lych_kab.destroy()
      open_raspisanie_window(user_id,db_connection)

    canvas = Canvas( lych_kab, bg = "#474747", height = 507, width = 833, bd = 0, highlightthickness = 0, relief = "ridge")

    canvas.place(x = 0, y = 0)
    button_image_1 = PhotoImage( file=relative_to_assets("button_1.png"))
    button_1 = Button( image=button_image_1, borderwidth=0, highlightthickness=0, command=lambda: update_balance(), relief="flat")
    button_1.place( x=450.0, y=425.0, width=187.0, height=52.0)

    button_image_2 = PhotoImage( file=relative_to_assets("button_2.png"))
    button_2 = Button( image=button_image_2, borderwidth=0, highlightthickness=0, command=lambda: view_tickets(), relief="flat")
    button_2.place( x=450.0, y=349.0, width=187.0, height=52.0)

    button_image_3 = PhotoImage( file=relative_to_assets("button_3.png"))
    button_3 = Button( image=button_image_3, borderwidth=0, highlightthickness=0, command=lambda: delete_account(), relief="flat")
    button_3.place( x=450.0, y=272.0, width=187.0, height=52.0)

    image_image_1 = PhotoImage( file=relative_to_assets("image_1.png"))
    image_1 = canvas.create_image(416.0,53.0,image=image_image_1)

    canvas.create_text(262.0,25.0,anchor="nw",text="Личный кабинет",fill="#000000",font=("Fruktur Regular", 36 * -1))

    image_image_2 = PhotoImage( file=relative_to_assets("image_2.png"))
    image_2 = canvas.create_image( 75.0, 162.0, image=image_image_2)

    canvas.create_rectangle( 143.0, 180.0, 775.0, 181.0, fill="#FFFFFF", outline="")

    canvas.create_rectangle(203.0,313.0,354.0,314.0,fill="#FFFFFF",outline="")

    user_inf0 = load_user_info()
    name = user_inf0[0] + " " + user_inf0[1]

    canvas.create_text( 144.0, 130.0, anchor="nw", text= name, fill="#FFFFFF", font=("Fruktur Regular", 36 * -1))

    canvas.create_text( 586.0, 130.0, anchor="nw", text="ID:", fill="#FFFFFF", font=("ABeeZee Regular", 36 * -1))

    canvas.create_text( 650.0, 130.0, anchor="nw", text=user_id, fill="#FFFFFF", font=("ABeeZee Regular", 36 * -1))

    canvas.create_text( 43.0, 262.0, anchor="nw",  text="Баланс:", fill="#FFFFFF", font=("Fruktur Regular", 36 * -1))

    money = canvas.create_text( 208.0, 270.0, anchor="nw", text=user_inf0[2], fill="#FFFFFF", font=("Fruktur Regular", 36 * -1))

    entry_image_1 = PhotoImage( file=relative_to_assets("entry_1.png"))
    entry_bg_1 = canvas.create_image( 228.5, 450.5, image=entry_image_1)
    entry_1 = Entry( bd=0, bg="#474747", fg="#000716", highlightthickness=0 ,foreground="white")
    entry_1.place( x=56.0, y=424.0, width=345.0, height=55.0)

    button_image_4 = PhotoImage( file=relative_to_assets("button_4.png"))
    button_4 = Button( image=button_image_4, borderwidth=0, highlightthickness=0, command=lambda: open_rasp_window_f_lk(user_id,db_connection), relief="flat")
    button_4.place( x=658.0, y=421.0, width=117.0, height=52.0)
    lych_kab.resizable(False, False)
    lych_kab.mainloop()

def open_raspisanie_window( user_id, db_connection):
    OUTPUT_PATH = Path(__file__).parent
    ASSETS_PATH = OUTPUT_PATH / Path(r"assets/frame3")

    def relative_to_assets(path: str) -> Path:
        return ASSETS_PATH / Path(path)
    def lk(user_id, db_connection):
        raspisanie.destroy()
        open_lychny_kabinet_window(user_id, db_connection)

    def buy_ticket(user_id, route_id, from_station, to_station, train_type, db_connection):
        try:
            cursor = db_connection.cursor()

            cursor.execute("BEGIN")


            cursor.execute("SELECT money FROM Users WHERE user_id = %s", (user_id,))
            user_balance = cursor.fetchone()[0]

            cursor.execute("SELECT price FROM Tickets WHERE user_id = %s AND route_id = %s", (user_id, route_id))
            ticket_price = cursor.fetchone()[0] if cursor.rowcount > 0 else 0

            if user_balance < ticket_price:
                messagebox.showerror("Ошибка", "На балансе недостаточно денег!")
                cursor.execute("ROLLBACK")
                return

            cursor.execute("UPDATE Users SET money = money - %s WHERE user_id = %s", (ticket_price, user_id))


            query = "CALL add_ticket(%s, %s, %s, %s, %s, CURRENT_DATE)"
            cursor.execute(query, (user_id, route_id, from_station, to_station, train_type))

            db_connection.commit()
            cursor.close()

            messagebox.showinfo("Успешно", "Билет успешно куплен!")
        except Exception as e:
            db_connection.rollback()
            messagebox.showerror("Ошибка", str(e))

    def buy_selected_ticket():
        selected_item = tree.focus()
        if selected_item:
            schedule_data = tree.item(selected_item, "values")
            schedule_id = schedule_data[0]
            to_station = entry_2.get()
            from_station = entry_1.get()

            cursor = db_connection.cursor()
            cursor.execute("SELECT * FROM name_to_id(%s)", (from_station,))
            from_station_id = cursor.fetchone()
            cursor.close()

            cursor = db_connection.cursor()
            cursor.execute("SELECT * FROM name_to_id(%s)", (to_station,))
            to_station_id = cursor.fetchone()
            cursor.close()

            if to_station_id:
                buy_ticket(user_id, schedule_data[5], from_station_id[0], to_station_id[0], schedule_data[1], db_connection)

    def show_schedule():
        from_station = entry_1.get()
        to_station = entry_2.get()

        cursor = db_connection.cursor()
        cursor.execute("SELECT * FROM name_to_id(%s)", (from_station,))
        from_station_id = cursor.fetchone()
        cursor.close()

        cursor = db_connection.cursor()
        cursor.execute("SELECT * FROM name_to_id(%s)", (to_station,))
        to_station_id = cursor.fetchone()
        cursor.close()

        cursor = db_connection.cursor()
        cursor.execute("SELECT * FROM get_train_schedule_with_price_2(%s, %s, %s)", (from_station_id[0], to_station_id[0], user_id))
        schedules = cursor.fetchall()
        cursor.close()

        for item in tree.get_children():
            tree.delete(item)
        for schedule in schedules:
            tree.insert("", "end", values=schedule)
    raspisanie = Tk()

    raspisanie.geometry("1800x900")
    raspisanie.configure(bg = "#474747")

    canvas = Canvas(raspisanie,bg = "#474747",height = 900,width = 1800,bd = 0,highlightthickness = 0,relief = "ridge")

    canvas.place(x = 0, y = 0)
    image_image_1 = PhotoImage( file=relative_to_assets("image_1.png"))
    image_1 = canvas.create_image( 900.0, 53.0, image=image_image_1)

    canvas.create_text(800.0, 15.0, anchor="nw", text="Расписание", fill="#000000", font=("Fruktur Regular", 48 * -1))

    canvas.create_text(70.0,180.0,anchor="nw",text="От:",fill="#FFFFFF",font=("Fruktur Regular", 48 * -1))

    canvas.create_text(586.0,180.0,anchor="nw",text="До:",fill="#FFFFFF",font=("Fruktur Regular", 48 * -1))

    box_stations = ('Зеленоград-Крюково', 'Тверь', 'Пл. Чуприняновка', 'Пл. Кузьминка', 'Пл. Межево', 'Редкино', 'Пл. Московское море', 'Завидово', 'Пл. Черничная', 'Решетниково', 'Пл. Ямуга', 'Клин', 'пл. Стреглово', 'пл. Покровка', 'пл. Головково', 'пл. Сенеж', 'Подсолнечная', 'пл. Березки-Дачные', 'Поварово-1', 'пл. Поваровка', 'пл. Радищево', 'пл. Алабушево', 'пл. Малино', 'пл. Фирсановская', 'Сходня', 'пл. Подрезково', 'пл. Новоподрезково', 'пл. Молжаниново', 'Химки', 'пл. Левобережная', 'пл. Ховрино', 'Грачёвская', 'пл. Моссельмаш', 'пл. Лихоборы', 'пл. Петровско-Разумовская', 'пл. Останкино', 'Пл. Рижская', 'Москва Ленинградская')


    style = ttk.Style()
    style.theme_use("default")

    entry_image_1 = PhotoImage( file=relative_to_assets("entry_1.png"))
    entry_bg_1 = canvas.create_image( 373.5, 207.5, image=entry_image_1)
    entry_1 = ttk.Combobox(raspisanie,background="#474747", values=box_stations)
    entry_1.place(x=239.0,y=180.0,width=270.0,height=56.0)

    style.configure("TCombobox", fieldbackground="#474747", background="#474747", foreground="white", selectbackground="#474747", selectforeground="white", font=("Fruktur Regular", 48 * -1))

    entry_image_2 = PhotoImage( file=relative_to_assets("entry_2.png"))
    entry_bg_2 = canvas.create_image( 889.5, 209.5, image=entry_image_2)
    entry_2 = ttk.Combobox(raspisanie,background="#474747", values=box_stations)
    entry_2.place( x=753.0, y=182.0, width=270.0, height=56.0)

    button_image_1 = PhotoImage( file=relative_to_assets("button_1.png"))
    button_1 = Button( image=button_image_1, borderwidth=0, highlightthickness=0, command=lambda: show_schedule(), relief="flat")
    button_1.place( x=1102.0, y=155.0, width=119.0, height=105.0)

    canvas.create_rectangle( 28.0, 311.0, 1766.0, 881.0, fill="#FFFFFF", outline="")

    button_image_2 = PhotoImage( file=relative_to_assets("button_2.png"))
    button_2 = Button( image=button_image_2, borderwidth=0, highlightthickness=0, command=lambda: buy_selected_ticket(), relief="flat")
    button_2.place( x=1274.0, y=155.0, width=119.0, height=105.0)

    button_image_3 = PhotoImage( file=relative_to_assets("button_3.png"))
    button_3 = Button( image=button_image_3, borderwidth=0, highlightthickness=0, command=lambda: lk(user_id, db_connection), relief="flat")
    button_3.place(x=1647.0,y=155.0,width=119.0,height=105.0)

    columns = ("train_number", "type", "departure_time", "arrival_time", 'station_name', 'route_id', 'cost')
    tree = ttk.Treeview(raspisanie, columns=columns, show="headings")

    tree.column("train_number", anchor="center", width=120)
    tree.column("type", anchor="center", width=200)
    tree.column("departure_time", anchor="center", width=200)
    tree.column("arrival_time", anchor="center", width=200)
    tree.column("station_name", anchor="center", width=200)
    tree.column("route_id", anchor="center", width=200)
    tree.column("cost", anchor="center", width=200)

    tree.heading("train_number", text="Номер поезда")
    tree.heading("type", text="Тип электрички")
    tree.heading("departure_time", text="Время отправления")
    tree.heading("arrival_time", text="Время прибытия")
    tree.heading("station_name", text="Название станции")
    tree.heading("route_id", text="Номер маршрута")
    tree.heading("cost", text="Цена за билет")

    style.configure("Treeview", background="#FFBF87", fieldbackground="#FFBF87", foreground="black")
    style.configure("Treeview.Heading", background="#FFBF87", fieldbackground="#FFBF87", foreground="black")
    style.map("Treeview", background=[("selected", "#F0A300")])

    tree.place(x=28, y=311, height=570, width=1738 )

    raspisanie.resizable(False, False)
    raspisanie.mainloop()

create_first_window()