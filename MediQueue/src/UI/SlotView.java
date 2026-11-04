package UI;

import Model.AvailableSlot;
import Services.SlotUnavailableException;
import javafx.geometry.Pos;
import javafx.scene.Parent;
import javafx.scene.control.Button;
import javafx.scene.control.Label;
import javafx.scene.control.ScrollPane;
import javafx.scene.control.ToggleButton;
import javafx.scene.control.ToggleGroup;
import javafx.scene.layout.FlowPane;
import javafx.scene.layout.HBox;
import javafx.scene.layout.Priority;
import javafx.scene.layout.StackPane;
import javafx.scene.layout.VBox;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.TreeMap;

/** Step 3 - FR-05..FR-08, FR-10, FR-11: pick a day and time, then book it. */
class SlotView {
    private static final String CONFIRM = "Confirm booking";
    private static final String NONE = "No time selected";

    private final KioskApp app;
    private final StackPane holder = new StackPane();
    private final Label error = Ui.errorBanner();
    private final Button confirm = Ui.primary(CONFIRM);
    private final Label selection = new Label(NONE);
    private AvailableSlot selected;
    private LocalDate activeDay;

    SlotView(KioskApp app) {
        this.app = app;
    }

    Parent build() {
        holder.setAlignment(Pos.TOP_LEFT);
        VBox.setVgrow(holder, Priority.ALWAYS);

        Label location = new Label(app.clinic.getLocation());
        location.getStyleClass().add("lead");

        confirm.setDisable(true);
        confirm.setOnAction(e -> book());
        selection.getStyleClass().add("selection");

        Button back = Ui.secondary("Back");
        back.setOnAction(e -> app.goClinics());
        Button cancel = Ui.secondary("Cancel");
        cancel.setOnAction(e -> app.startOver());

        load();
        VBox body = new VBox(16, location, error, holder);
        return Ui.page(2, app.clinic.getName(), "اختر الموعد المناسب", body,
                back, cancel, Ui.spacer(), selection, confirm);
    }

    private void load() {
        select(null);
        holder.getChildren().setAll(Ui.loading("Loading available times..."));
        Ui.async(() -> app.service.getSlotsForClinic(app.clinic.getClinicId()),
                this::render,
                err -> holder.getChildren().setAll(Ui.errorState(Ui.friendly(err))));
    }

    private void render(List<AvailableSlot> slots) {
        if (slots.isEmpty()) { // FR-10
            Button other = Ui.primary("Choose another clinic");
            other.setOnAction(e -> app.goClinics());
            holder.getChildren().setAll(Ui.emptyState(
                    "No appointment times are available for this clinic.",
                    "لا توجد مواعيد متاحة لهذه العيادة حالياً", other));
            return;
        }

        Map<LocalDate, List<AvailableSlot>> byDay = new TreeMap<>();
        for (AvailableSlot s : slots) {
            byDay.computeIfAbsent(s.getStartTime().toLocalDate(), d -> new ArrayList<>()).add(s);
        }
        if (activeDay == null || !byDay.containsKey(activeDay)) {
            activeDay = byDay.keySet().iterator().next();
        }

        FlowPane times = new FlowPane(12, 12);
        ToggleGroup dayGroup = new ToggleGroup();
        HBox days = new HBox(10);
        for (Map.Entry<LocalDate, List<AvailableSlot>> entry : byDay.entrySet()) {
            LocalDate day = entry.getKey();
            List<AvailableSlot> daySlots = entry.getValue();
            ToggleButton chip = new ToggleButton(day.format(KioskApp.DAY) + "\n" + daySlots.size() + " times");
            chip.getStyleClass().add("day-chip");
            chip.setToggleGroup(dayGroup);
            chip.setSelected(day.equals(activeDay));
            chip.setOnAction(e -> {
                chip.setSelected(true); // a day always stays selected
                activeDay = day;
                fillTimes(times, daySlots);
            });
            days.getChildren().add(chip);
        }
        fillTimes(times, byDay.get(activeDay));

        ScrollPane dayScroll = new ScrollPane(days);
        dayScroll.setFitToHeight(true);
        dayScroll.setVbarPolicy(ScrollPane.ScrollBarPolicy.NEVER);
        dayScroll.getStyleClass().add("chip-scroll");

        ScrollPane timeScroll = new ScrollPane(times);
        timeScroll.setFitToWidth(true);
        VBox.setVgrow(timeScroll, Priority.ALWAYS);

        holder.getChildren().setAll(new VBox(12,
                section("1.  Choose a day"), dayScroll,
                section("2.  Choose a time"), timeScroll));
    }

    private void fillTimes(FlowPane pane, List<AvailableSlot> daySlots) {
        pane.getChildren().clear();
        ToggleGroup group = new ToggleGroup();
        for (AvailableSlot slot : daySlots) {
            ToggleButton chip = new ToggleButton(slot.getStartTime().format(KioskApp.TIME));
            chip.getStyleClass().add("time-chip");
            chip.setToggleGroup(group);
            chip.setSelected(selected != null && selected.getSlotId() == slot.getSlotId());
            chip.setOnAction(e -> select(chip.isSelected() ? slot : null));
            pane.getChildren().add(chip);
        }
    }

    private void select(AvailableSlot slot) {
        selected = slot;
        confirm.setDisable(slot == null);
        selection.setText(slot == null ? NONE : slot.getStartTime().format(KioskApp.FULL));
    }

    private void book() {
        if (selected == null) {
            return;
        }
        AvailableSlot slot = selected;
        Ui.hide(error);
        confirm.setDisable(true);
        confirm.setText("Booking...");
        Ui.async(() -> app.service.confirmBooking(slot.getSlotId(), app.patient.getPatientId()),
                app::goConfirmation,
                err -> {
                    confirm.setText(CONFIRM);
                    if (err instanceof SlotUnavailableException) { // FR-11
                        Ui.showError(error, "Sorry, that time was just booked by someone else. Please choose another time.\n"
                                + err.getMessage());
                        load();
                    } else {
                        confirm.setDisable(false);
                        Ui.showError(error, Ui.friendly(err));
                    }
                });
    }

    private static Label section(String text) {
        Label l = new Label(text);
        l.getStyleClass().add("section");
        return l;
    }
}
