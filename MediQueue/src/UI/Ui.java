package UI;

import Services.SlotUnavailableException;
import javafx.concurrent.Task;
import javafx.geometry.Insets;
import javafx.geometry.Pos;
import javafx.scene.Node;
import javafx.scene.control.Button;
import javafx.scene.control.Label;
import javafx.scene.control.ProgressIndicator;
import javafx.scene.layout.BorderPane;
import javafx.scene.layout.HBox;
import javafx.scene.layout.Priority;
import javafx.scene.layout.Region;
import javafx.scene.layout.VBox;

import java.sql.SQLException;
import java.util.concurrent.Callable;
import java.util.function.Consumer;

/** Shared layout pieces and helpers used by every kiosk screen. */
final class Ui {
    private static final String[] STEPS = {"Identify", "Clinic", "Time", "Confirm"};

    private Ui() {
    }

    /** Standard page: top bar, bilingual heading, body, optional footer. step = 0..3, or -1 for none. */
    static BorderPane page(int step, String titleEn, String titleAr, Node body, Node... footerItems) {
        BorderPane root = new BorderPane();
        root.setTop(topBar(step));

        Label h1 = new Label(titleEn);
        h1.getStyleClass().add("h1");
        h1.setWrapText(true);
        Label h1Ar = new Label(titleAr);
        h1Ar.getStyleClass().add("h1-ar");

        VBox content = new VBox(new VBox(2, h1, h1Ar), body);
        content.getStyleClass().add("content");
        VBox.setVgrow(body, Priority.ALWAYS);
        root.setCenter(content);

        if (footerItems.length > 0) {
            HBox footer = new HBox(footerItems);
            footer.getStyleClass().add("footer");
            root.setBottom(footer);
        }
        return root;
    }

    private static HBox topBar(int step) {
        Label logo = new Label("MQ");
        logo.getStyleClass().add("logo");
        Label brand = new Label("MediQueue");
        brand.getStyleClass().add("brand");
        Label sub = new Label("Self-Service Reception  ·  الاستقبال الذاتي");
        sub.getStyleClass().add("brand-sub");

        HBox bar = new HBox(logo, new VBox(1, brand, sub), spacer());
        bar.getStyleClass().add("topbar");

        if (step >= 0) {
            HBox steps = new HBox(6);
            steps.setAlignment(Pos.CENTER_RIGHT);
            for (int i = 0; i < STEPS.length; i++) {
                Label s = new Label((i < step ? "✓  " : (i + 1) + "  ") + STEPS[i]);
                s.getStyleClass().add("step");
                if (i == step) {
                    s.getStyleClass().add("step-active");
                } else if (i < step) {
                    s.getStyleClass().add("step-done");
                }
                steps.getChildren().add(s);
            }
            bar.getChildren().add(steps);
        }
        return bar;
    }

    static Button primary(String text) {
        Button b = new Button(text);
        b.getStyleClass().add("btn-primary");
        return b;
    }

    static Button secondary(String text) {
        Button b = new Button(text);
        b.getStyleClass().add("btn-secondary");
        return b;
    }

    static Region spacer() {
        Region r = new Region();
        HBox.setHgrow(r, Priority.ALWAYS);
        return r;
    }

    static Label errorBanner() {
        Label l = new Label();
        l.getStyleClass().add("error-banner");
        l.setWrapText(true);
        l.setMaxWidth(Double.MAX_VALUE);
        hide(l);
        return l;
    }

    static void showError(Label banner, String message) {
        banner.setText(message);
        banner.setVisible(true);
        banner.setManaged(true);
    }

    static void hide(Node n) {
        n.setVisible(false);
        n.setManaged(false);
    }

    static Node loading(String text) {
        ProgressIndicator p = new ProgressIndicator();
        p.setPrefSize(56, 56);
        Label l = new Label(text);
        l.getStyleClass().add("muted");
        VBox v = new VBox(14, p, l);
        v.setAlignment(Pos.CENTER);
        v.setPadding(new Insets(48));
        v.setMaxWidth(Double.MAX_VALUE);
        return v;
    }

    /** Friendly empty state (e.g. FR-10: no times available). */
    static Node emptyState(String en, String ar, Node... actions) {
        Label title = new Label(en);
        title.getStyleClass().add("empty-title");
        title.setWrapText(true);
        Label sub = new Label(ar);
        sub.getStyleClass().add("muted");
        VBox v = new VBox(12, title, sub);
        if (actions.length > 0) {
            HBox row = new HBox(12, actions);
            row.setAlignment(Pos.CENTER);
            row.setPadding(new Insets(12, 0, 0, 0));
            v.getChildren().add(row);
        }
        v.getStyleClass().add("panel");
        v.setAlignment(Pos.CENTER);
        v.setMaxWidth(720);
        return v;
    }

    static Node errorState(String message) {
        Label l = errorBanner();
        showError(l, message);
        l.setMaxWidth(720);
        return l;
    }

    /** Runs database work off the UI thread so the screen never freezes. */
    static <T> void async(Callable<T> work, Consumer<T> onSuccess, Consumer<Throwable> onError) {
        Task<T> task = new Task<>() {
            @Override
            protected T call() throws Exception {
                return work.call();
            }
        };
        task.setOnSucceeded(e -> onSuccess.accept(task.getValue()));
        task.setOnFailed(e -> onError.accept(task.getException()));
        Thread t = new Thread(task, "mediqueue-db");
        t.setDaemon(true);
        t.start();
    }

    /** NFR-09: turn exceptions into messages a patient can understand. */
    static String friendly(Throwable t) {
        if (t instanceof IllegalArgumentException || t instanceof SlotUnavailableException) {
            return t.getMessage();
        }
        if (t instanceof SQLException) {
            return "Could not reach the hospital database. Please ask a staff member for help.\n"
                    + "تعذّر الاتصال بقاعدة البيانات\n("
                    + t.getMessage() + ")";
        }
        return t.getMessage() != null ? t.getMessage() : t.toString();
    }
}
