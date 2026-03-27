package com.moko.ble.lib.event;


import com.moko.ble.lib.task.OrderTaskResponse;

public class OrderTaskResponseEvent {
    private String action;
    private OrderTaskResponse response;
    private String macAddress;

    public String getAction() {
        return action;
    }

    public void setAction(String action) {
        this.action = action;
    }

    public OrderTaskResponse getResponse() {
        return response;
    }

    public void setResponse(OrderTaskResponse response) {
        this.response = response;
    }

    public String getMacAddress() {
        return macAddress;
    }

    public void setMacAddress(String macAddress) {
        this.macAddress = macAddress;
    }
}
