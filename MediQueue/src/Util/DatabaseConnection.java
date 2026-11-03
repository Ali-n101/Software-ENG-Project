package Util;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;

public class DatabaseConnection {
    private static final String URL = "jdbc:mysql://localhost:3306/mediqueue?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=UTC";
    private static String user;
    private static String password;

    public static void setCredentials(String dbUser, String dbPassword) {
        user = dbUser;
        password = dbPassword;
    }

    public static Connection getConnection() throws SQLException {
        if (user == null || password == null) {
            throw new SQLException("Database credentials are not set.");
        }
        return DriverManager.getConnection(URL, user, password);
    }
}
