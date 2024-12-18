import tkinter as tk
from tkinter import ttk, messagebox
import psycopg2
import random

# Подключение к базе данных
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


# Авторизация пользователя
def login_user(email, password, db_connection):
    try:
        cursor = db_connection.cursor()
        query = "SELECT * FROM Users WHERE mail = %s AND user_password = %s"
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


# Покупка билета
def buy_ticket(user_id, route_id, from_station, to_station, train_type, db_connection):
    try:
        cursor = db_connection.cursor()

        # Начинаем транзакцию
        cursor.execute("BEGIN")

        # Получаем текущий баланс пользователя
        cursor.execute("SELECT money FROM Users WHERE user_id = %s", (user_id,))
        user_balance = cursor.fetchone()[0]

        # Получаем стоимость билета
        cursor.execute("SELECT price FROM Tickets WHERE user_id = %s AND route_id = %s", (user_id, route_id))
        ticket_price = cursor.fetchone()[0] if cursor.rowcount > 0 else 0

        # Проверяем, хватает ли денег
        if user_balance < ticket_price:
            messagebox.showerror("Ошибка", "На балансе недостаточно денег!")
            cursor.execute("ROLLBACK")  # Откат транзакции
            return

        # Уменьшаем баланс пользователя
        cursor.execute("UPDATE Users SET money = money - %s WHERE user_id = %s", (ticket_price, user_id))

        # Добавляем билет в таблицу Tickets
        query = "CALL add_ticket(%s, %s, %s, %s, %s, CURRENT_DATE)"
        cursor.execute(query, (user_id, route_id, from_station, to_station, train_type))

        # Фиксируем транзакцию
        db_connection.commit()
        cursor.close()

        messagebox.showinfo("Успешно", "Билет успешно куплен!")
    except Exception as e:
        # Откат транзакции в случае ошибки
        db_connection.rollback()
        messagebox.showerror("Ошибка", str(e))


# Функция для центрирования окна
def center_window(window, width, height):
    screen_width = window.winfo_screenwidth()
    screen_height = window.winfo_screenheight()
    x = (screen_width - width) // 2
    y = (screen_height - height) // 2
    window.geometry(f"{width}x{height}+{x}+{y}")


# Окно расписания и покупки билетов
def schedule_window(user_id, db_connection):
    def show_schedule():
        from_station = from_station_combo.get()
        to_station = to_station_combo.get()

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

    def buy_selected_ticket():
        selected_item = tree.focus()
        if selected_item:
            schedule_data = tree.item(selected_item, "values")
            schedule_id = schedule_data[0]
            to_station = to_station_combo.get()
            from_station = from_station_combo.get()

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

    def open_personal_account():
        schedule.destroy()
        personal_account_window(user_id, db_connection)

    schedule = tk.Tk()
    schedule.title("Расписание")

    # Центрирование окна
    center_window(schedule, 1800, 900)

    # Кнопка "Личный кабинет" в правом верхнем углу
    personal_account_button = tk.Button(schedule, text="Личный кабинет", command=open_personal_account)
    personal_account_button.pack(side="top", anchor="ne", padx=10, pady=10)

    box_stations = ('Зеленоград-Крюково', 'Тверь', 'Пл. Чуприняновка', 'Пл. Кузьминка', 'Пл. Межево', 'Редкино', 'Пл. Московское море', 'Завидово', 'Пл. Черничная', 'Решетниково', 'Пл. Ямуга', 'Клин', 'пл. Стреглово', 'пл. Покровка', 'пл. Головково', 'пл. Сенеж', 'Подсолнечная', 'пл. Березки-Дачные', 'Поварово-1', 'пл. Поваровка', 'пл. Радищево', 'пл. Алабушево', 'пл. Малино', 'пл. Фирсановская', 'Сходня', 'пл. Подрезково', 'пл. Новоподрезково', 'пл. Молжаниново', 'Химки', 'пл. Левобережная', 'пл. Ховрино', 'Грачёвская', 'пл. Моссельмаш', 'пл. Лихоборы', 'пл. Петровско-Разумовская', 'пл. Останкино', 'Пл. Рижская', 'Москва Ленинградская')

    # Станция отправления
    tk.Label(schedule, text="Станция отправления").pack()
    from_station_combo = ttk.Combobox(schedule, values=box_stations)
    from_station_combo.pack()

    # Станция назначения
    tk.Label(schedule, text="Станция назначения").pack()
    to_station_combo = ttk.Combobox(schedule, values=box_stations)
    to_station_combo.pack()

    # Кнопка для отображения расписания
    tk.Button(schedule, text="Показать расписание", command=show_schedule).pack(pady=30)

    # Таблица расписаний
    columns = ("train_number", "type", "departure_time", "arrival_time", 'station_name', 'route_id', 'cost')
    tree = ttk.Treeview(schedule, columns=columns, show="headings", height=20)

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

    tree.pack(fill="both", expand=True, pady=30)

    # Кнопка для покупки билета
    tk.Button(schedule, text="Купить билет", command=buy_selected_ticket).pack()

    schedule.mainloop()


# Окно личного кабинета
def personal_account_window(user_id, db_connection):
    def load_user_info():
        cursor = db_connection.cursor()
        cursor.execute("SELECT first_name, last_name, money FROM Users WHERE user_id = %s", (user_id,))
        user_info = cursor.fetchone()
        cursor.close()
        return user_info

    def update_balance():
        amount = amount_entry.get()
        if not amount.isdigit() or int(amount) < 0:
            messagebox.showerror("Ошибка", "Введите неотрицательное целое число!")
            return

        try:
            cursor = db_connection.cursor()
            cursor.execute("UPDATE Users SET money = money + %s WHERE user_id = %s", (int(amount), user_id))
            db_connection.commit()
            cursor.close()
            messagebox.showinfo("Успешно", f"Баланс пополнен на {amount}!")
            user_info = load_user_info()
            balance_label.config(text=f"Баланс: {user_info[2]}")
        except Exception as e:
            messagebox.showerror("Ошибка", str(e))

    def delete_account():
        confirm = messagebox.askyesno("Подтверждение", "Вы уверены, что хотите удалить аккаунт?")
        if confirm:
            try:
                # Удаляем все билеты пользователя
                cursor = db_connection.cursor()
                cursor.execute("DELETE FROM Tickets WHERE user_id = %s", (user_id,))
                db_connection.commit()

                # Удаляем пользователя
                cursor.execute("DELETE FROM Users WHERE user_id = %s", (user_id,))
                db_connection.commit()
                cursor.close()

                messagebox.showinfo("Успешно", "Аккаунт и все купленные билеты удалены!")
                personal_account.destroy()
                login_window()
            except Exception as e:
                messagebox.showerror("Ошибка", str(e))

    def view_tickets():
        cursor = db_connection.cursor()
        cursor.execute("SELECT * FROM Tickets WHERE user_id = %s", (user_id,))
        tickets = cursor.fetchall()
        cursor.close()

        if not tickets:
            messagebox.showinfo("Информация", "У вас нет купленных билетов.")
            return

        ticket_window = tk.Toplevel(personal_account)
        ticket_window.title("Купленные билеты")

        columns = ("ticket_id", "user_id", "route_id", "from_station_id", "to_station_id", "date", "price", "total_price", "train_type")
        tree = ttk.Treeview(ticket_window, columns=columns, show="headings", height=10)

        for col in columns:
            tree.heading(col, text=col)
            tree.column(col, anchor="center", width=100)

        for ticket in tickets:
            tree.insert("", "end", values=ticket)

        tree.pack(fill="both", expand=True)

    def return_to_schedule():
        personal_account.destroy()
        schedule_window(user_id, db_connection)

    personal_account = tk.Tk()
    personal_account.title("Личный кабинет")

    # Центрирование окна
    center_window(personal_account, 600, 400)

    user_info = load_user_info()

    tk.Label(personal_account, text=f"User ID: {user_id}").pack()
    tk.Label(personal_account, text=f"Имя: {user_info[0]}").pack()
    tk.Label(personal_account, text=f"Фамилия: {user_info[1]}").pack()
    balance_label = tk.Label(personal_account, text=f"Баланс: {user_info[2]}")
    balance_label.pack()

    tk.Label(personal_account, text="Сумма для пополнения:").pack()
    amount_entry = tk.Entry(personal_account)
    amount_entry.pack()

    tk.Button(personal_account, text="Пополнить счёт", command=update_balance).pack()
    tk.Button(personal_account, text="Удалить аккаунт", command=delete_account).pack()
    tk.Button(personal_account, text="Купленные билеты", command=view_tickets).pack()
    tk.Button(personal_account, text="Вернуться в расписание", command=return_to_schedule).pack()

    personal_account.mainloop()


# Окно регистрации
def registration_window(db_connection):
    def register_user():
        first_name = first_name_entry.get()
        last_name = last_name_entry.get()
        email = email_entry.get()
        phone_number = phone_number_entry.get()
        transport_concession = concession_combo.get()
        password = password_entry.get()

        try:
            cursor = db_connection.cursor()
            query = "CALL add_user(%s, %s, %s, %s, %s, %s, %s)"
            cursor.execute(query, (first_name, last_name, email, phone_number, random.randint(100, 1000), password, transport_concession))
            db_connection.commit()

            # Получаем user_id только что зарегистрированного пользователя
            cursor.execute("SELECT user_id FROM Users WHERE mail = %s", (email,))
            user_id = cursor.fetchone()[0]
            cursor.close()

            messagebox.showinfo("Успешно", "Регистрация прошла успешно!")
            registration.destroy()

            # Переходим в окно расписания
            schedule_window(user_id, db_connection)
        except Exception as e:
            messagebox.showerror("Ошибка", str(e))

    registration = tk.Tk()
    registration.title("Регистрация")

    # Центрирование окна
    center_window(registration, 600, 400)

    tk.Label(registration, text="Имя").grid(row=0, column=0, padx=10, pady=10)
    first_name_entry = tk.Entry(registration)
    first_name_entry.grid(row=0, column=1, padx=10, pady=10)

    tk.Label(registration, text="Фамилия").grid(row=1, column=0, padx=10, pady=10)
    last_name_entry = tk.Entry(registration)
    last_name_entry.grid(row=1, column=1, padx=10, pady=10)

    tk.Label(registration, text="Email").grid(row=2, column=0, padx=10, pady=10)
    email_entry = tk.Entry(registration)
    email_entry.grid(row=2, column=1, padx=10, pady=10)

    tk.Label(registration, text="Номер телефона (X-XXX-XXX-XX-XX)").grid(row=3, column=0, padx=10, pady=10)
    phone_number_entry = tk.Entry(registration)
    phone_number_entry.grid(row=3, column=1, padx=10, pady=10)

    tk.Label(registration, text="Льгота").grid(row=4, column=0, padx=10, pady=10)
    concession_combo = ttk.Combobox(registration, values=["без льгот", "пол цены", "бесплатно"])
    concession_combo.grid(row=4, column=1, padx=10, pady=10)

    tk.Label(registration, text="Пароль").grid(row=5, column=0, padx=10, pady=10)
    password_entry = tk.Entry(registration, show="*")
    password_entry.grid(row=5, column=1, padx=10, pady=10)

    tk.Button(registration, text="Зарегистрироваться", command=register_user).grid(row=6, column=0, columnspan=2, pady=20)

    registration.mainloop()


# Окно авторизации
def login_window():
    def try_login():
        email = email_entry.get()
        password = password_entry.get()
        user = login_user(email, password, db_connection)
        if user:
            login.destroy()
            schedule_window(user[0], db_connection)
        else:
            messagebox.showerror("Ошибка", "Неверные учетные данные.")

    def open_registration():
        login.destroy()
        registration_window(db_connection)

    db_connection = connect_to_db()
    if not db_connection:
        return

    login = tk.Tk()
    login.title("Авторизация")

    # Центрирование окна
    center_window(login, 600, 400)

    tk.Label(login, text="Email").pack()
    email_entry = tk.Entry(login)
    email_entry.pack()

    tk.Label(login, text="Пароль").pack()
    password_entry = tk.Entry(login, show="*")
    password_entry.pack()

    tk.Button(login, text="Войти", command=try_login).pack()
    tk.Button(login, text="Регистрация", command=open_registration).pack()

    login.mainloop()


if __name__ == "__main__":
    login_window()