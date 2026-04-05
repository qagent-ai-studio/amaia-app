package com.moko.support.d;

import android.bluetooth.BluetoothDevice;
import android.bluetooth.BluetoothGatt;
import android.bluetooth.BluetoothGattCharacteristic;
import android.content.Context;

import com.elvishew.xlog.XLog;
import com.moko.ble.lib.MokoBleLib;
import com.moko.ble.lib.MokoBleManager;
import com.moko.ble.lib.MokoConstants;
import com.moko.ble.lib.event.ConnectStatusEvent;
import com.moko.ble.lib.event.OrderTaskResponseEvent;
import com.moko.ble.lib.task.OrderTask;
import com.moko.ble.lib.task.OrderTaskResponse;
import com.moko.support.d.entity.ExportData;
import com.moko.support.d.entity.OrderCHAR;
import com.moko.support.d.handler.MokoCharacteristicHandler;

import com.moko.support.d.task.PasswordTask;
import com.moko.support.d.task.ParamsTask;

import org.greenrobot.eventbus.EventBus;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.UUID;

public class DMokoSupport extends MokoBleLib {
    private HashMap<OrderCHAR, BluetoothGattCharacteristic> mCharacteristicMap;

    private static volatile DMokoSupport INSTANCE;

    private Context mContext;

    private MokoBleConfig mBleConfig;

    private String mPassword = "";

    private String currentDeviceMac;

    private DMokoSupport() {
        //no instance
    }

    public DMokoSupport(Context context, String deviceMac) {
        this.mContext = context;
        this.currentDeviceMac = deviceMac;
        super.init(context);
    }

    public void setPassword(String password) {
        mPassword = password != null ? password : "";
        if (mBleConfig != null) {
            mBleConfig.setPassword(mPassword);
        }
    }

    public static DMokoSupport getInstance() {
        if (INSTANCE == null) {
            synchronized (DMokoSupport.class) {
                if (INSTANCE == null) {
                    INSTANCE = new DMokoSupport();
                }
            }
        }
        return INSTANCE;
    }

    public void init(Context context) {
        mContext = context;
        super.init(context);
    }

    public MokoBleConfig getMokoBleConfig() {
        return mBleConfig;
    }

    public void writePasswordDirectly(byte[] data) {
        if (mBleConfig != null) {
            mBleConfig.writeDirectly(mBleConfig.getPasswordCharacteristic(), data);
        }
    }

    public void forceConnDevice(String address) {
        android.bluetooth.BluetoothAdapter adapter = android.bluetooth.BluetoothAdapter.getDefaultAdapter();
        if (adapter == null || !adapter.isEnabled()) return;
        final android.bluetooth.BluetoothDevice device = adapter.getRemoteDevice(address);
        if (device == null) return;
        boolean sysConnected = isConnDevice(address);
        android.util.Log.d("MkButtonSDK", "forceConnDevice: isConnDevice=" + sysConnected + " for " + address);
        if (sysConnected && mBleConfig != null) {
            android.util.Log.d("MkButtonSDK", "forceConnDevice: closing stale GATT + resetting BleManager");
            mBleConfig.closeDirectly();
            mBleConfig = null;
        }
        new android.os.Handler(android.os.Looper.getMainLooper()).post(() ->
            getMokoBleManager().connect(device).retry(5, 200).timeout(50000).enqueue()
        );
    }

    public void startKeepAlive() {
        android.util.Log.d("MkButtonSDK", "Setting connection interval to 200ms for mac=" + currentDeviceMac);
        try {
            sendOrder(com.moko.support.d.OrderTaskAssembler.setConnectInterval(200));
        } catch (Exception e) {
            android.util.Log.e("MkButtonSDK", "Failed to set connect interval: " + e.getMessage());
        }
    }

    @Override
    public MokoBleManager getMokoBleManager() {
        if (mBleConfig == null) {
            mBleConfig = new MokoBleConfig(mContext, this);
            if (mPassword != null && !mPassword.isEmpty()) {
                mBleConfig.setPassword(mPassword);
            }
        }
        return mBleConfig;
    }

    ///////////////////////////////////////////////////////////////////////////
    // connect
    ///////////////////////////////////////////////////////////////////////////

    @Override
    public void onDeviceConnected(BluetoothGatt gatt) {
        currentDeviceMac = gatt.getDevice().getAddress();
        mCharacteristicMap = new MokoCharacteristicHandler().getCharacteristics(gatt);
        ConnectStatusEvent connectStatusEvent = new ConnectStatusEvent();
        connectStatusEvent.setAction(MokoConstants.ACTION_DISCOVER_SUCCESS);
        connectStatusEvent.setMacAddress(currentDeviceMac);
        EventBus.getDefault().post(connectStatusEvent);
    }

    @Override
    public void onDeviceDisconnected(BluetoothDevice device) {
        String mac = device.getAddress();
        ConnectStatusEvent connectStatusEvent = new ConnectStatusEvent();
        connectStatusEvent.setAction(MokoConstants.ACTION_DISCONNECTED);
        connectStatusEvent.setMacAddress(mac);
        EventBus.getDefault().post(connectStatusEvent);
    }

    @Override
    public BluetoothGattCharacteristic getCharacteristic(Enum orderCHAR) {
        return mCharacteristicMap.get(orderCHAR);
    }

    ///////////////////////////////////////////////////////////////////////////
    // order
    ///////////////////////////////////////////////////////////////////////////

    @Override
    public boolean isCHARNull() {
        if (mCharacteristicMap == null || mCharacteristicMap.isEmpty()) {
            disConnectBle();
            return true;
        }
        return false;
    }

    @Override
    public void orderFinish() {
        OrderTaskResponseEvent event = new OrderTaskResponseEvent();
        event.setAction(MokoConstants.ACTION_ORDER_FINISH);
        event.setMacAddress(currentDeviceMac);
        EventBus.getDefault().post(event);
    }

    @Override
    public void orderTimeout(OrderTaskResponse response) {
        android.util.Log.e("MkButtonSDK", "ORDER TIMEOUT mac=" + currentDeviceMac);
        OrderTaskResponseEvent event = new OrderTaskResponseEvent();
        event.setAction(MokoConstants.ACTION_ORDER_TIMEOUT);
        event.setResponse(response);
        event.setMacAddress(currentDeviceMac);
        EventBus.getDefault().post(event);
    }

    @Override
    public void orderResult(OrderTaskResponse response) {
        OrderTaskResponseEvent event = new OrderTaskResponseEvent();
        event.setAction(MokoConstants.ACTION_ORDER_RESULT);
        event.setResponse(response);
        event.setMacAddress(currentDeviceMac);
        EventBus.getDefault().post(event);
    }

    @Override
    public boolean orderResponseValid(BluetoothGattCharacteristic characteristic, OrderTask orderTask) {
        final UUID responseUUID = characteristic.getUuid();
        final OrderCHAR orderCHAR = (OrderCHAR) orderTask.orderCHAR;
        return responseUUID.equals(orderCHAR.getUuid());
    }


    @Override
    public boolean orderNotify(BluetoothGattCharacteristic characteristic, byte[] value) {
        final UUID responseUUID = characteristic.getUuid();
        android.util.Log.d("MkButtonSDK", "orderNotify mac=" + currentDeviceMac + " uuid=" + responseUUID.toString() +
            " value=" + com.moko.ble.lib.utils.MokoUtils.bytesToHexString(value));

        if (responseUUID.equals(OrderCHAR.CHAR_PARAMS.getUuid()) && value != null && value.length >= 3 &&
            (value[0] & 0xFF) == 0xEB && (value[1] & 0xFF) == 0x00) {
            int key = value[2] & 0xFF;
            if (key == 0x57 || key == 0x2C || key == 0x51 || key == 0x01 || key == 0x5B) {
                android.util.Log.d("MkButtonSDK", "Init/keep-alive response 0x" + String.format("%02X", key) + " mac=" + currentDeviceMac);
                return true;
            }
        }

        OrderCHAR orderCHAR = null;
        if (responseUUID.equals(OrderCHAR.CHAR_DISCONNECT.getUuid())) {
            orderCHAR = OrderCHAR.CHAR_DISCONNECT;
        }
        if (responseUUID.equals(OrderCHAR.CHAR_ACC.getUuid())) {
            orderCHAR = OrderCHAR.CHAR_ACC;
        }
        if (responseUUID.equals(OrderCHAR.CHAR_SINGLE_TRIGGER.getUuid())) {
            orderCHAR = OrderCHAR.CHAR_SINGLE_TRIGGER;
        }
        if (responseUUID.equals(OrderCHAR.CHAR_DOUBLE_TRIGGER.getUuid())) {
            orderCHAR = OrderCHAR.CHAR_DOUBLE_TRIGGER;
        }
        if (responseUUID.equals(OrderCHAR.CHAR_LONG_TRIGGER.getUuid())) {
            orderCHAR = OrderCHAR.CHAR_LONG_TRIGGER;
        }
        if (responseUUID.equals(OrderCHAR.CHAR_CLICK_EVENT.getUuid())) {
            orderCHAR = OrderCHAR.CHAR_CLICK_EVENT;
        }
        if (responseUUID.equals(OrderCHAR.CHAR_LONG_CONNECTION.getUuid())) {
            orderCHAR = OrderCHAR.CHAR_LONG_CONNECTION;
        }
        if (orderCHAR == null)
            return false;

        XLog.i(orderCHAR.name());
        OrderTaskResponse response = new OrderTaskResponse();
        response.orderCHAR = orderCHAR;
        response.responseValue = value;
        OrderTaskResponseEvent event = new OrderTaskResponseEvent();
        event.setAction(MokoConstants.ACTION_CURRENT_DATA);
        event.setResponse(response);
        event.setMacAddress(currentDeviceMac);
        EventBus.getDefault().post(event);
        android.util.Log.d("MkButtonSDK", "Click event posted: " + orderCHAR.name() + " mac=" + currentDeviceMac);
        return true;
    }

    public void enableSingleTriggerNotify() {
        if (mBleConfig != null)
            mBleConfig.enableSingleTriggerNotify();
    }

    public void disableSingleTriggerNotify() {
        if (mBleConfig != null)
            mBleConfig.disableSingleTriggerNotify();
    }

    public void enableDoubleTriggerNotify() {
        if (mBleConfig != null)
            mBleConfig.enableDoubleTriggerNotify();
    }

    public void disableDoubleTriggerNotify() {
        if (mBleConfig != null)
            mBleConfig.disableDoubleTriggerNotify();
    }

    public void enableLongTriggerNotify() {
        if (mBleConfig != null)
            mBleConfig.enableLongTriggerNotify();
    }

    public void disableLongTriggerNotify() {
        if (mBleConfig != null)
            mBleConfig.disableLongTriggerNotify();
    }

    public void enableAccNotify() {
        if (mBleConfig != null)
            mBleConfig.enableAccNotify();
    }

    public void disableAccNotify() {
        if (mBleConfig != null)
            mBleConfig.disableAccNotify();
    }

    public void enableClickEventNotify() {
        if (mBleConfig != null)
            mBleConfig.enableClickEventNotify();
    }

    public void disableClickEventNotify() {
        if (mBleConfig != null)
            mBleConfig.disableClickEventNotify();
    }

    public void enableLongConnectionNotify() {
        if (mBleConfig != null)
            mBleConfig.enableLongConnectionNotify();
    }

    public void disableLongConnectionNotify() {
        if (mBleConfig != null)
            mBleConfig.disableLongConnectionNotify();
    }

    public ArrayList<ExportData> exportSingleEvents;
    public StringBuilder storeSingleEventString;
    public ArrayList<ExportData> exportDoubleEvents;
    public StringBuilder storeDoubleEventString;
    public ArrayList<ExportData> exportLongEvents;
    public StringBuilder storeLongEventString;
    public ArrayList<ExportData> exportLongConnectionEvents;
    public StringBuilder storeLongConnectionEventString;
}
